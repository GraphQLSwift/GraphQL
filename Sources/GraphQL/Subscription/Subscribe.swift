import Dispatch
import Runtime
import RxSwift
import NIO

/**
 * Implements the "Subscribe" algorithm described in the GraphQL specification.
 *
 * Returns a Promise which resolves to either an AsyncIterator (if successful)
 * or an ExecutionResult (error). The promise will be rejected if the schema or
 * other arguments to this function are invalid, or if the resolved event stream
 * is not an async iterable.
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, a GraphQL Response (ExecutionResult) with
 * descriptive errors and no data will be returned.
 *
 * If the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the promise will resolve to a single
 * ExecutionResult containing `errors` and no `data`.
 *
 * If the operation succeeded, the promise resolves to an AsyncIterator, which
 * yields a stream of ExecutionResults representing the response stream.
 *
 * Accepts either an object with named arguments, or individual arguments.
 */
func subscribe(
    queryStrategy: QueryFieldExecutionStrategy,
    mutationStrategy: MutationFieldExecutionStrategy,
    subscriptionStrategy: SubscriptionFieldExecutionStrategy,
    instrumentation: Instrumentation,
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: Any,
    context: Any,
    eventLoopGroup: EventLoopGroup,
    variableValues: [String: Map] = [:],
    operationName: String? = nil,
    fieldResolver: GraphQLFieldResolve? = nil,
    subscribeFieldResolver: GraphQLFieldResolve? = nil
) -> EventLoopFuture<SubscriptionResult> {
    
    
    let sourceFuture = createSourceEventStream(
        queryStrategy: queryStrategy,
        mutationStrategy: mutationStrategy,
        subscriptionStrategy: subscriptionStrategy,
        instrumentation: instrumentation,
        schema: schema,
        documentAST: documentAST,
        rootValue: rootValue,
        context: context,
        eventLoopGroup: eventLoopGroup,
        variableValues: variableValues,
        operationName: operationName,
        subscribeFieldResolver: subscribeFieldResolver
    )

    // For each payload yielded from a subscription, map it over the normal
    // GraphQL `execute` function, with `payload` as the rootValue.
    // This implements the "MapSourceToResponseEvent" algorithm described in
    // the GraphQL specification. The `execute` function provides the
    // "ExecuteSubscriptionEvent" algorithm, as it is nearly identical to the
    // "ExecuteQuery" algorithm, for which `execute` is also used.
    func mapSourceToResponse(payload: Any) -> EventLoopFuture<GraphQLResult> {
        return execute(
            queryStrategy: queryStrategy,
            mutationStrategy: mutationStrategy,
            subscriptionStrategy: subscriptionStrategy,
            instrumentation: instrumentation,
            schema: schema,
            documentAST: documentAST,
            rootValue: payload, // Make payload the root value
            context: context,
            eventLoopGroup: eventLoopGroup,
            variableValues: variableValues,
            operationName: operationName
        )
    }
    return sourceFuture.flatMap{ subscriptionResult -> EventLoopFuture<SubscriptionResult> in
        do {
            let subscriptionObserver = try subscriptionResult.get()
            let eventObserver = subscriptionObserver.map { eventPayload -> GraphQLResult in
                return try! mapSourceToResponse(payload: eventPayload).wait() // TODO Remove this wait
            }
            // TODO Making a future here feels it indicates a mistake...
            return eventLoopGroup.next().makeSucceededFuture(SubscriptionResult.success(eventObserver))
        } catch let graphQLError as GraphQLError {
            return eventLoopGroup.next().makeSucceededFuture(SubscriptionResult.failure(graphQLError))
        }
    }
}

/**
 * Implements the "CreateSourceEventStream" algorithm described in the
 * GraphQL specification, resolving the subscription source event stream.
 *
 * Returns a Promise which resolves to either an AsyncIterable (if successful)
 * or an ExecutionResult (error). The promise will be rejected if the schema or
 * other arguments to this function are invalid, or if the resolved event stream
 * is not an async iterable.
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, a GraphQL Response (ExecutionResult) with
 * descriptive errors and no data will be returned.
 *
 * If the the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the promise will resolve to a single
 * ExecutionResult containing `errors` and no `data`.
 *
 * If the operation succeeded, the promise resolves to the AsyncIterable for the
 * event stream returned by the resolver.
 *
 * A Source Event Stream represents a sequence of events, each of which triggers
 * a GraphQL execution for that event.
 *
 * This may be useful when hosting the stateful subscription service in a
 * different process or machine than the stateless GraphQL execution engine,
 * or otherwise separating these two steps. For more on this, see the
 * "Supporting Subscriptions at Scale" information in the GraphQL specification.
 */
func createSourceEventStream(
    queryStrategy: QueryFieldExecutionStrategy,
    mutationStrategy: MutationFieldExecutionStrategy,
    subscriptionStrategy: SubscriptionFieldExecutionStrategy,
    instrumentation: Instrumentation,
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: Any,
    context: Any,
    eventLoopGroup: EventLoopGroup,
    variableValues: [String: Map] = [:],
    operationName: String? = nil,
    subscribeFieldResolver: GraphQLFieldResolve? = nil
) -> EventLoopFuture<SourceEventStreamResult> {

    let executeStarted = instrumentation.now
    
    do {
        // If a valid context cannot be created due to incorrect arguments,
        // this will throw an error.
        let exeContext = try buildExecutionContext(
            queryStrategy: queryStrategy,
            mutationStrategy: mutationStrategy,
            subscriptionStrategy: subscriptionStrategy,
            instrumentation: instrumentation,
            schema: schema,
            documentAST: documentAST,
            rootValue: rootValue,
            context: context,
            eventLoopGroup: eventLoopGroup,
            rawVariableValues: variableValues,
            operationName: operationName
            // TODO shouldn't we be including the subscribeFieldResolver??
        )
        return try executeSubscription(context: exeContext, eventLoopGroup: eventLoopGroup)
    } catch let error as GraphQLError {
        instrumentation.operationExecution(
            processId: processId(),
            threadId: threadId(),
            started: executeStarted,
            finished: instrumentation.now,
            schema: schema,
            document: documentAST,
            rootValue: rootValue,
            eventLoopGroup: eventLoopGroup,
            variableValues: variableValues,
            operation: nil,
            errors: [error],
            result: nil
        )

        return eventLoopGroup.next().makeSucceededFuture(SourceEventStreamResult.failure(error))
    } catch {
        return eventLoopGroup.next().makeSucceededFuture(SourceEventStreamResult.failure(GraphQLError(error)))
    }
}

func executeSubscription(
    context: ExecutionContext,
    eventLoopGroup: EventLoopGroup
) throws -> EventLoopFuture<SourceEventStreamResult> {
    
    // Get the first node
    let type = try getOperationRootType(schema: context.schema, operation: context.operation)
    var inputFields: [String:[Field]] = [:]
    var visitedFragmentNames: [String:Bool] = [:]
    let fields = try collectFields(
        exeContext: context,
        runtimeType: type,
        selectionSet: context.operation.selectionSet,
        fields: &inputFields,
        visitedFragmentNames: &visitedFragmentNames
    )
    let responseNames = fields.keys
    let responseName = responseNames.first! // TODO add error handling here
    let fieldNodes = fields[responseName]!
    let fieldNode = fieldNodes.first!
    
    guard let fieldDef = getFieldDef(schema: context.schema, parentType: type, fieldAST: fieldNode) else {
        throw GraphQLError.init(
            message: "`The subscription field '\(fieldNode.name)' is not defined.`",
            nodes: fieldNodes
        )
    }
    
    let path = IndexPath.init().appending(fieldNode.name.value)
    let info = buildResolveInfo(
        context: context,
        fieldDef: fieldDef,
        fieldASTs: fieldNodes,
        parentType: type,
        path: path
    )
    
    // Implements the "ResolveFieldEventStream" algorithm from GraphQL specification.
    // It differs from "ResolveFieldValue" due to providing a different `resolveFn`.

    // Build a map of arguments from the field.arguments AST, using the
    // variables scope to fulfill any variable references.
    let args = try getArgumentValues(argDefs: fieldDef.args, argASTs: fieldNode.arguments, variableValues: context.variableValues)

    // The resolve function's optional third argument is a context value that
    // is provided to every resolve function within an execution. It is commonly
    // used to represent an authenticated user, or request-specific caches.
    let contextValue = context.context

    // Call the `subscribe()` resolver or the default resolver to produce an
    // Observable yielding raw payloads.
    let resolve = fieldDef.subscribe ?? defaultResolve
    
    // Get the resolve func, regardless of if its result is normal
    // or abrupt (error).
    let resolvedFutureOrError = resolveOrError(
        resolve: resolve,
        source: context.rootValue,
        args: args,
        context: contextValue,
        eventLoopGroup: eventLoopGroup,
        info: info
    )
    
    let resolvedFuture:Future<Any?>
    switch resolvedFutureOrError {
    case let .failure(error):
        throw error
    case let .success(success):
        resolvedFuture = success
    }
    return resolvedFuture.map { resolved -> SourceEventStreamResult in
        if !context.errors.isEmpty {
            // TODO improve this to return multiple errors if we have them.
            return SourceEventStreamResult.failure(context.errors.first!)
        } else if let error = resolved as? GraphQLError {
            return SourceEventStreamResult.failure(error)
        } else if let observable = resolved as? Observable<Any> {
            return SourceEventStreamResult.success(observable)
        } else if resolved == nil {
            return SourceEventStreamResult.failure(
                GraphQLError(message: "Resolved subscription was nil")
            )
        } else {
            return SourceEventStreamResult.failure(
                GraphQLError(message: "Subscription field resolver must return an Observable<Any>, not \(Swift.type(of:resolved))")
            )
        }
    }
}

typealias SubscriptionResult = Result<Observable<GraphQLResult>, GraphQLError>
typealias SourceEventStreamResult = Result<Observable<Any>, GraphQLError>
