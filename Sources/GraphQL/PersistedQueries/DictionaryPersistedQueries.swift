
/// A simple PersistedQueries implementation
public struct DictionaryPersistedQueries<IdType: Hashable>: PersistQueryExecution {
    public typealias Id = IdType

    let schema: GraphQLSchema
    let queries: [Id: Document]

    /// - Parameters:
    ///   - schema: The GraphQL type system to use when validating and executing a query.
    ///   - sources: A dictionary of sources that make up the persisted queries.
    /// - Throws: throws GraphQLError if an error occurs while parsing and validating the persistant queries.
    public init(schema: GraphQLSchema, sources: [Id: Source]) throws {
        var queries: [Id: Document] = [:]
        try sources.forEach { id, source in
            let documentAST = try parse(source: source)
            let validationErrors = validate(schema: schema, ast: documentAST)
            if let firstError = validationErrors.first {
                throw firstError
            }
            queries[id] = documentAST
        }
        self.schema = schema
        self.queries = queries
    }

    public func execute(id: Id, rootValue: Any, contextValue: Any, variableValues: [String: Map], operationName: String?) throws -> Map {
        guard let documentAST = queries[id] else {
            throw GraphQLError(message: "Unknown query \"\(id)\".")
        }
        return try GraphQL.execute(
            schema: schema,
            documentAST: documentAST,
            rootValue: rootValue,
            contextValue: contextValue,
            variableValues: variableValues,
            operationName: operationName
        )
    }
}
