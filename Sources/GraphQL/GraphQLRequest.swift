import Foundation

/// A GraphQL request object, containing `query`, `operationName`, and `variables` fields
public struct GraphQLRequest: Equatable, Codable, Sendable {
    public var query: String
    public var operationName: String?
    public var variables: [String: Map]

    public init(query: String, operationName: String? = nil, variables: [String: Map] = [:]) {
        self.query = query
        self.operationName = operationName
        self.variables = variables
    }

    // To handle decoding with a default of variables = []
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decode(String.self, forKey: .query)
        operationName = try container.decodeIfPresent(String.self, forKey: .operationName)
        variables = try container.decodeIfPresent([String: Map].self, forKey: .variables) ?? [:]
    }

    /// Boolean indicating if the GraphQL request is a subscription operation.
    /// This operation performs an entire AST parse on the GraphQL request, so consider
    /// performance when calling multiple times.
    ///
    /// - Returns: True if request is a subscription, false if it is an atomic operation (like
    /// `query` or `mutation`)
    public func isSubscription() throws -> Bool {
        return try operationType() == .subscription
    }

    /// The type of operation perfomed by the request.
    /// This operation performs an entire AST parse on the GraphQL request, so consider
    /// performance when calling multiple times.
    ///
    /// - Returns: The operation type performed by the request
    public func operationType() throws -> OperationType {
        let documentAST = try GraphQL.parse(
            source: Source(body: query, name: "GraphQL request")
        )
        let firstOperation = documentAST.definitions.compactMap { $0 as? OperationDefinition }.first
        guard let operationType = firstOperation?.operation else {
            throw GraphQLError(message: "GraphQL operation type could not be determined")
        }
        return operationType
    }
}
