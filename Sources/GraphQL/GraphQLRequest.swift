import Foundation

/// A GraphQL request object, containing `query`, `operationName`, and `variables` fields
public struct GraphQLRequest: Equatable, Codable {
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
        self.query = try container.decode(String.self, forKey: .query)
        self.operationName = try container.decodeIfPresent(String.self, forKey: .operationName)
        self.variables = try container.decodeIfPresent([String: Map].self, forKey: .variables) ?? [:]
    }
    
    /// Boolean indicating if the GraphQL request is a subscription operation.
    /// This operation performs an entire AST parse on the GraphQL request, so consider
    /// performance when calling multiple times.
    ///
    /// - Returns: True if request is a subscription, false if it is an atomic operation (like `query` or `mutation`)
    public func isSubscription() throws -> Bool {
        let documentAST = try GraphQL.parse(
            instrumentation: NoOpInstrumentation,
            source: Source(body: self.query, name: "GraphQL request")
        )
        let firstOperation = documentAST.definitions.compactMap { $0 as? OperationDefinition }.first
        guard let operationType = firstOperation?.operation else {
            throw GraphQLError(message: "GraphQL operation type could not be determined")
        }
        return operationType == .subscription
    }
}

