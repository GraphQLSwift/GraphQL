import OrderedCollections

/**
 * Implements the "Subscribe" algorithm described in the GraphQL specification.
 *
 * Returns a `Result` that either succeeds with an `AsyncThrowingStream`, or fails with `GraphQLErrors`.
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, the `Result` will fails with descriptive errors.
 *
 * If the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the `Result` will fail with errors.
 *
 * If the operation succeeded, the `Result` will succeed with an `AsyncThrowingStream` of `GraphQLResult`s
 * representing the response stream.
 */
func subscribe(
    queryStrategy: QueryFieldExecutionStrategy,
    mutationStrategy: MutationFieldExecutionStrategy,
    subscriptionStrategy: SubscriptionFieldExecutionStrategy,
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: any Sendable,
    context: any Sendable,
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> Result<AsyncThrowingStream<GraphQLResult, Error>, GraphQLErrors> {
    let sourceResult = try await createSourceEventStream(
        queryStrategy: queryStrategy,
        mutationStrategy: mutationStrategy,
        subscriptionStrategy: subscriptionStrategy,
        schema: schema,
        documentAST: documentAST,
        rootValue: rootValue,
        context: context,
        variableValues: variableValues,
        operationName: operationName
    )

    return sourceResult.map { sourceStream in
        AsyncThrowingStream<GraphQLResult, Error> {
            // The type-cast below is required on Swift <6. Once we drop Swift 5 support it may be
            // removed.
            var iterator = sourceStream.makeAsyncIterator() as (any AsyncIteratorProtocol)
            guard let eventPayload = try await iterator.next() else {
                return nil
            }
            // Despite the warning, we must force unwrap because on optional unwrap, compiler throws:
            // `marker protocol 'Sendable' cannot be used in a conditional cast`
            let rootValue = eventPayload as! (any Sendable)
            return try await execute(
                queryStrategy: queryStrategy,
                mutationStrategy: mutationStrategy,
                subscriptionStrategy: subscriptionStrategy,
                schema: schema,
                documentAST: documentAST,
                rootValue: rootValue,
                context: context,
                variableValues: variableValues,
                operationName: operationName
            )
        }
    }
}

/**
 * Implements the "CreateSourceEventStream" algorithm described in the
 * GraphQL specification, resolving the subscription source event stream.
 *
 * Returns a Result that either succeeds with an `AsyncSequence` or fails with `GraphQLErrors`.
 *
 * If the client-provided arguments to this function do not result in a
 * compliant subscription, the `Result` will fail with descriptive errors.
 *
 * If the source stream could not be created due to faulty subscription
 * resolver logic or underlying systems, the `Result` will fail with errors.
 *
 * If the operation succeeded, the `Result` will succeed with an AsyncSequence for the
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
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: any Sendable,
    context: any Sendable,
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> Result<any AsyncSequence & Sendable, GraphQLErrors> {
    // If a valid context cannot be created due to incorrect arguments,
    // this will throw an error.
    let exeContext = try buildExecutionContext(
        queryStrategy: queryStrategy,
        mutationStrategy: mutationStrategy,
        subscriptionStrategy: subscriptionStrategy,
        schema: schema,
        documentAST: documentAST,
        rootValue: rootValue,
        context: context,
        rawVariableValues: variableValues,
        operationName: operationName
    )
    do {
        return try await executeSubscription(context: exeContext)
    } catch let error as GraphQLError {
        // If it is a GraphQLError, report it as a failure.
        return .failure(.init([error]))
    } catch let errors as GraphQLErrors {
        // If it is a GraphQLErrors, report it as a failure.
        return .failure(errors)
    } catch {
        // Otherwise treat the error as a system-class error and re-throw it.
        throw error
    }
}

func executeSubscription(
    context: ExecutionContext
) async throws -> Result<any AsyncSequence & Sendable, GraphQLErrors> {
    // Get the first node
    let type = try getOperationRootType(schema: context.schema, operation: context.operation)
    var inputFields: OrderedDictionary<String, [Field]> = [:]
    var visitedFragmentNames: [String: Bool] = [:]
    let fields = try collectFields(
        exeContext: context,
        runtimeType: type,
        selectionSet: context.operation.selectionSet,
        fields: &inputFields,
        visitedFragmentNames: &visitedFragmentNames
    )

    // If query is valid, fields should have at least 1 member
    guard
        let responseName = fields.keys.first,
        let fieldNodes = fields[responseName],
        let fieldNode = fieldNodes.first
    else {
        throw GraphQLError(
            message: "Subscription field resolution resulted in no field nodes."
        )
    }

    guard let fieldDef = getFieldDef(schema: context.schema, parentType: type, fieldAST: fieldNode)
    else {
        throw GraphQLError(
            message: "The subscription field '\(fieldNode.name.value)' is not defined.",
            nodes: fieldNodes
        )
    }

    // Implements the "ResolveFieldEventStream" algorithm from GraphQL specification.
    // It differs from "ResolveFieldValue" due to providing a different `resolveFn`.

    // Build a map of arguments from the field.arguments AST, using the
    // variables scope to fulfill any variable references.
    let args = try getArgumentValues(
        argDefs: fieldDef.args,
        argASTs: fieldNode.arguments,
        variables: context.variableValues
    )

    // The resolve function's optional third argument is a context value that
    // is provided to every resolve function within an execution. It is commonly
    // used to represent an authenticated user, or request-specific caches.
    let contextValue = context.context

    // The resolve function's optional fourth argument is a collection of
    // information about the current execution state.
    let path = IndexPath().appending(fieldNode.name.value)
    let info = GraphQLResolveInfo(
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
    let resolvedOrError = await resolveOrError(
        resolve: resolve,
        source: context.rootValue,
        args: args,
        context: contextValue,
        info: info
    )

    let resolved: Any?
    switch resolvedOrError {
    case let .failure(error):
        if let graphQLError = error as? GraphQLError {
            throw graphQLError
        } else {
            throw GraphQLError(error)
        }
    case let .success(success):
        resolved = success
    }
    if !context.errors.isEmpty {
        return .failure(.init(context.errors))
    } else if let error = resolved as? GraphQLError {
        return .failure(.init([error]))
    } else if let stream = resolved as? any AsyncSequence {
        // Despite the warning, we must force unwrap because on optional unwrap, compiler throws:
        // `marker protocol 'Sendable' cannot be used in a conditional cast`
        return .success(stream as! (any AsyncSequence & Sendable))
    } else if resolved == nil {
        return .failure(.init([
            GraphQLError(message: "Resolved subscription was nil"),
        ]))
    } else {
        let resolvedObj = resolved as AnyObject
        return .failure(.init([
            GraphQLError(
                message: "Subscription field resolver must return an AsyncSequence. Received: '\(resolvedObj)'"
            ),
        ]))
    }
}
