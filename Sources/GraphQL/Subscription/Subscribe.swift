import NIO
import OrderedCollections

/**
 * Implements the "Subscribe" algorithm described in the GraphQL specification.
 *
 * Returns a future which resolves to a SubscriptionResult containing either
 * a SubscriptionObservable (if successful), or GraphQLErrors (error).
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, the future will resolve to a
 * SubscriptionResult containing `errors` and no `observable`.
 *
 * If the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the future will resolve to a
 * SubscriptionResult containing `errors` and no `observable`.
 *
 * If the operation succeeded, the future will resolve to a SubscriptionResult,
 * containing an `observable` which yields a stream of GraphQLResults
 * representing the response stream.
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
    operationName: String? = nil
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
        operationName: operationName
    )
    
    return sourceFuture.map{ sourceResult -> SubscriptionResult in
        if let sourceStream = sourceResult.stream {
            let subscriptionStream = sourceStream.map { eventPayload -> Future<GraphQLResult> in
                
                // For each payload yielded from a subscription, map it over the normal
                // GraphQL `execute` function, with `payload` as the rootValue.
                // This implements the "MapSourceToResponseEvent" algorithm described in
                // the GraphQL specification. The `execute` function provides the
                // "ExecuteSubscriptionEvent" algorithm, as it is nearly identical to the
                // "ExecuteQuery" algorithm, for which `execute` is also used.
                return execute(
                    queryStrategy: queryStrategy,
                    mutationStrategy: mutationStrategy,
                    subscriptionStrategy: subscriptionStrategy,
                    instrumentation: instrumentation,
                    schema: schema,
                    documentAST: documentAST,
                    rootValue: eventPayload,
                    context: context,
                    eventLoopGroup: eventLoopGroup,
                    variableValues: variableValues,
                    operationName: operationName
                )
            }
            return SubscriptionResult(stream: subscriptionStream, errors: sourceResult.errors)
        } else {
            return SubscriptionResult(errors: sourceResult.errors)
        }
    }
}

/**
 * Implements the "CreateSourceEventStream" algorithm described in the
 * GraphQL specification, resolving the subscription source event stream.
 *
 * Returns a Future which resolves to a SourceEventStreamResult, containing
 * either an Observable (if successful) or GraphQLErrors (error).
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, the future will resolve to a
 * SourceEventStreamResult containing `errors` and no `observable`.
 *
 * If the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the future will resolve to a
 * SourceEventStreamResult containing `errors` and no `observable`.
 *
 * If the operation succeeded, the future will resolve to a SubscriptionResult,
 * containing an `observable` which yields a stream of event objects
 * returned by the subscription resolver.
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
    operationName: String? = nil
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

        return eventLoopGroup.next().makeSucceededFuture(SourceEventStreamResult(errors: [error]))
    } catch {
        return eventLoopGroup.next().makeSucceededFuture(SourceEventStreamResult(errors: [GraphQLError(error)]))
    }
}

func executeSubscription(
    context: ExecutionContext,
    eventLoopGroup: EventLoopGroup
) throws -> EventLoopFuture<SourceEventStreamResult> {
    
    // Get the first node
    let type = try getOperationRootType(schema: context.schema, operation: context.operation)
    var inputFields: OrderedDictionary<String, [Field]> = [:]
    var visitedFragmentNames: [String:Bool] = [:]
    let fields = try collectFields(
        exeContext: context,
        runtimeType: type,
        selectionSet: context.operation.selectionSet,
        fields: &inputFields,
        visitedFragmentNames: &visitedFragmentNames
    )
    // If query is valid, fields is guaranteed to have at least 1 member
    let responseName = fields.keys.first!
    let fieldNodes = fields[responseName]!
    let fieldNode = fieldNodes.first!
    
    guard let fieldDef = getFieldDef(schema: context.schema, parentType: type, fieldAST: fieldNode) else {
        throw GraphQLError(
            message: "The subscription field '\(fieldNode.name.value)' is not defined.",
            nodes: fieldNodes
        )
    }
    
    // Implements the "ResolveFieldEventStream" algorithm from GraphQL specification.
    // It differs from "ResolveFieldValue" due to providing a different `resolveFn`.

    // Build a map of arguments from the field.arguments AST, using the
    // variables scope to fulfill any variable references.
    let args = try getArgumentValues(argDefs: fieldDef.args, argASTs: fieldNode.arguments, variableValues: context.variableValues)

    // The resolve function's optional third argument is a context value that
    // is provided to every resolve function within an execution. It is commonly
    // used to represent an authenticated user, or request-specific caches.
    let contextValue = context.context
    
    // The resolve function's optional fourth argument is a collection of
    // information about the current execution state.
    let path = IndexPath.init().appending(fieldNode.name.value)
    let info = GraphQLResolveInfo.init(
        fieldName: fieldDef.name,
        fieldASTs: fieldNodes,
        returnType: fieldDef.type,
        parentType: type,
        path: path,
        schema: context.schema,
        fragments: context.fragments,
        rootValue: context.rootValue,
        operation: context.operation,
        variableValues: context.variableValues
    )

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
        if let graphQLError = error as? GraphQLError {
            throw graphQLError
        } else {
            throw GraphQLError(error)
        }
    case let .success(success):
        resolvedFuture = success
    }
    return resolvedFuture.map { resolved -> SourceEventStreamResult in
        if !context.errors.isEmpty {
            return SourceEventStreamResult(errors: context.errors)
        } else if let error = resolved as? GraphQLError {
            return SourceEventStreamResult(errors: [error])
        } else if let stream = resolved as? EventStream<Any> {
            return SourceEventStreamResult(stream: stream)
        } else if resolved == nil {
            return SourceEventStreamResult(errors: [
                GraphQLError(message: "Resolved subscription was nil")
            ])
        } else {
            let resolvedObj = resolved as AnyObject
            return SourceEventStreamResult(errors: [
                GraphQLError(
                    message: "Subscription field resolver must return EventStream<Any>. Received: '\(resolvedObj)'"
                )
            ])
        }
    }
}

// Subscription resolvers MUST return observables that are declared as 'Any' due to Swift not having covariant generic support for type
// checking. Normal resolvers for subscription fields should handle type casting, same as resolvers for query fields.
struct SourceEventStreamResult {
    public let stream: EventStream<Any>?
    public let errors: [GraphQLError]
    
    public init(stream: EventStream<Any>? = nil, errors: [GraphQLError] = []) {
        self.stream = stream
        self.errors = errors
    }
}
