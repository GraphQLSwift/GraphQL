
public struct GraphQLResult: Equatable, Codable, Sendable, CustomStringConvertible {
    public var data: Map?
    public var errors: [GraphQLError]

    public init(data: Map? = nil, errors: [GraphQLError] = []) {
        self.data = data
        self.errors = errors
    }

    enum CodingKeys: String, CodingKey {
        case data
        case errors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(Map.self, forKey: .data)
        errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let data = data {
            try container.encode(data, forKey: .data)
        }

        if !errors.isEmpty {
            try container.encode(errors, forKey: .errors)
        }
    }

    public var description: String {
        guard
            let data = try? GraphQLJSONEncoder().encode(self),
            let dataString = String(data: data, encoding: .utf8)
        else {
            return "Unable to encode GraphQLResult"
        }
        return dataString
    }
}

/// SubscriptionResult wraps the observable and error data returned by the subscribe request.
public struct SubscriptionResult {
    public let stream: AsyncThrowingStream<GraphQLResult, Error>?
    public let errors: [GraphQLError]

    public init(
        stream: AsyncThrowingStream<GraphQLResult, Error>? = nil,
        errors: [GraphQLError] = []
    ) {
        self.stream = stream
        self.errors = errors
    }
}

/// This is the primary entry point function for fulfilling GraphQL operations
/// by parsing, validating, and executing a GraphQL document along side a
/// GraphQL schema.
///
/// More sophisticated GraphQL servers, such as those which persist queries,
/// may wish to separate the validation and execution phases to a static time
/// tooling step, and a server runtime step.
///
/// - parameter queryStrategy:        The field execution strategy to use for query requests
/// - parameter mutationStrategy:     The field execution strategy to use for mutation requests
/// - parameter subscriptionStrategy: The field execution strategy to use for subscription requests
/// - parameter schema:               The GraphQL type system to use when validating and executing a
/// query.
/// - parameter request:              A GraphQL language formatted string representing the requested
/// operation.
/// - parameter rootValue:            The value provided as the first argument to resolver functions
/// on the top level type (e.g. the query object type).
/// - parameter contextValue:         A context value provided to all resolver functions functions
/// - parameter variableValues:       A mapping of variable name to runtime value to use for all
/// variables defined in the `request`.
/// - parameter operationName:        The name of the operation to use if `request` contains
/// multiple possible operations. Can be omitted if `request` contains only one operation.
///
/// - throws: throws GraphQLError if an error occurs while parsing the `request`.
///
/// - returns: returns a `Map` dictionary containing the result of the query inside the key `data`
/// and any validation or execution errors inside the key `errors`. The value of `data` might be
/// `null` if, for example, the query is invalid. It's possible to have both `data` and `errors` if
/// an error occurs only in a specific field. If that happens the value of that field will be `null`
/// and there will be an error inside `errors` specifying the reason for the failure and the path of
/// the failed field.
public func graphql(
    queryStrategy: QueryFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    mutationStrategy: MutationFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    subscriptionStrategy: SubscriptionFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    validationRules: [(ValidationContext) -> Visitor] = [],
    schema: GraphQLSchema,
    request: String,
    rootValue: Any = (),
    context: Any = (),
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> GraphQLResult {
    let source = Source(body: request, name: "GraphQL request")
    let documentAST = try parse(source: source)
    let validationErrors = validate(
        schema: schema,
        ast: documentAST,
        rules: validationRules
    )

    guard validationErrors.isEmpty else {
        return GraphQLResult(errors: validationErrors)
    }

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

/// This is the primary entry point function for fulfilling GraphQL operations
/// by using persisted queries.
///
/// - parameter queryStrategy:        The field execution strategy to use for query requests
/// - parameter mutationStrategy:     The field execution strategy to use for mutation requests
/// - parameter subscriptionStrategy: The field execution strategy to use for subscription requests
/// - parameter queryRetrieval:       The PersistedQueryRetrieval instance to use for looking up
/// queries
/// - parameter queryId:              The id of the query to execute
/// - parameter rootValue:            The value provided as the first argument to resolver functions
/// on the top level type (e.g. the query object type).
/// - parameter contextValue:         A context value provided to all resolver functions functions
/// - parameter variableValues:       A mapping of variable name to runtime value to use for all
/// variables defined in the `request`.
/// - parameter operationName:        The name of the operation to use if `request` contains
/// multiple possible operations. Can be omitted if `request` contains only one operation.
///
/// - throws: throws GraphQLError if an error occurs while parsing the `request`.
///
/// - returns: returns a `Map` dictionary containing the result of the query inside the key `data`
/// and any validation or execution errors inside the key `errors`. The value of `data` might be
/// `null` if, for example, the query is invalid. It's possible to have both `data` and `errors` if
/// an error occurs only in a specific field. If that happens the value of that field will be `null`
/// and there will be an error inside `errors` specifying the reason for the failure and the path of
/// the failed field.
public func graphql<Retrieval: PersistedQueryRetrieval>(
    queryStrategy: QueryFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    mutationStrategy: MutationFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    subscriptionStrategy: SubscriptionFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    queryRetrieval: Retrieval,
    queryId: Retrieval.Id,
    rootValue: Any = (),
    context: Any = (),
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> GraphQLResult {
    switch try queryRetrieval.lookup(queryId) {
    case .unknownId:
        throw GraphQLError(message: "Unknown query id")
    case let .parseError(parseError):
        throw parseError
    case let .validateErrors(_, validationErrors):
        return GraphQLResult(errors: validationErrors)
    case let .result(schema, documentAST):
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

/// This is the primary entry point function for fulfilling GraphQL subscription
/// operations by parsing, validating, and executing a GraphQL subscription
/// document along side a GraphQL schema.
///
/// More sophisticated GraphQL servers, such as those which persist queries,
/// may wish to separate the validation and execution phases to a static time
/// tooling step, and a server runtime step.
///
/// - parameter queryStrategy:        The field execution strategy to use for query requests
/// - parameter mutationStrategy:     The field execution strategy to use for mutation requests
/// - parameter subscriptionStrategy: The field execution strategy to use for subscription requests
/// - parameter schema:               The GraphQL type system to use when validating and executing a
/// query.
/// - parameter request:              A GraphQL language formatted string representing the requested
/// operation.
/// - parameter rootValue:            The value provided as the first argument to resolver functions
/// on the top level type (e.g. the query object type).
/// - parameter contextValue:         A context value provided to all resolver functions
/// - parameter variableValues:       A mapping of variable name to runtime value to use for all
/// variables defined in the `request`.
/// - parameter operationName:        The name of the operation to use if `request` contains
/// multiple possible operations. Can be omitted if `request` contains only one operation.
///
/// - throws: throws GraphQLError if an error occurs while parsing the `request`.
///
/// - returns: returns a SubscriptionResult containing the subscription observable inside the key
/// `observable` and any validation or execution errors inside the key `errors`. The
/// value of `observable` might be `null` if, for example, the query is invalid. It's not possible
/// to have both `observable` and `errors`. The observable payloads are
/// GraphQLResults which contain the result of the query inside the key `data` and any validation or
/// execution errors inside the key `errors`. The value of `data` might be `null`.
/// It's possible to have both `data` and `errors` if an error occurs only in a specific field. If
/// that happens the value of that field will be `null` and there
/// will be an error inside `errors` specifying the reason for the failure and the path of the
/// failed field.
public func graphqlSubscribe(
    queryStrategy: QueryFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    mutationStrategy: MutationFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    subscriptionStrategy: SubscriptionFieldExecutionStrategy = SerialFieldExecutionStrategy(),
    validationRules: [(ValidationContext) -> Visitor] = [],
    schema: GraphQLSchema,
    request: String,
    rootValue: Any = (),
    context: Any = (),
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> SubscriptionResult {
    let source = Source(body: request, name: "GraphQL Subscription request")
    let documentAST = try parse(source: source)
    let validationErrors = validate(
        schema: schema,
        ast: documentAST,
        rules: validationRules
    )

    guard validationErrors.isEmpty else {
        return SubscriptionResult(errors: validationErrors)
    }

    return try await subscribe(
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
