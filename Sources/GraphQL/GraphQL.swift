/// This is the primary entry point function for fulfilling GraphQL operations
/// by parsing, validating, and executing a GraphQL document along side a
/// GraphQL schema.
///
/// More sophisticated GraphQL servers, such as those which persist queries,
/// may wish to separate the validation and execution phases to a static time
/// tooling step, and a server runtime step.
///
/// - parameter schema:         The GraphQL type system to use when validating and executing a query.
/// - parameter request:        A GraphQL language formatted string representing the requested operation.
/// - parameter rootValue:      The value provided as the first argument to resolver functions on the top level type (e.g. the query object type).
/// - parameter contextValue:   contextValue description
/// - parameter variableValues: A mapping of variable name to runtime value to use for all variables defined in the `request`.
/// - parameter operationName:  The name of the operation to use if `request` contains multiple possible operations. Can be omitted if `request` contains only one operation.
///
/// - throws: throws value description
///
/// - returns: return value description
public func graphql(
    schema: GraphQLSchema,
    request: String,
    rootValue: Map = .null,
    contextValue: Map = .null,
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) throws -> Map {
    let source = Source(body: request, name: "GraphQL request")
    let documentAST = try parse(source: source)
    let validationErrors = try validate(schema: schema, ast: documentAST)

    guard validationErrors.isEmpty else {
        return ["errors": validationErrors.map]
    }

    return try execute(
        schema: schema,
        documentAST: documentAST,
        rootValue: rootValue,
        contextValue: contextValue,
        variableValues: variableValues,
        operationName: operationName
    )
}
