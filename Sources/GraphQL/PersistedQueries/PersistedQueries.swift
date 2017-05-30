/// Protocol to provide support for executing persist queries.
public protocol PersistQueryExecution {
    associatedtype Id
    ///
    /// - parameter id:             The id of the persistant query that you want to execute.
    /// - parameter rootValue:      The value provided as the first argument to resolver functions on the top level type (e.g. the query object type).
    /// - parameter contextValue:   A context value provided to all resolver functions functions
    /// - parameter variableValues: A mapping of variable name to runtime value to use for all variables defined in the `request`.
    /// - parameter operationName:  The name of the operation to use if `request` contains multiple possible operations. Can be omitted if `request` contains only one operation.
    ///
    /// - throws: throws GraphQLError if an error occurs while loading that persistant query.
    ///
    /// - returns: returns a `Map` dictionary containing the result of the query inside the key `data` and any validation or execution errors inside the key `errors`. The value of `data` might be `null` if, for example, the query is invalid. It's possible to have both `data` and `errors` if an error occurs only in a specific field. If that happens the value of that field will be `null` and there will be an error inside `errors` specifying the reason for the failure and the path of the failed field.
    func execute(id: Id, rootValue: Any, contextValue: Any, variableValues: [String: Map], operationName: String?) throws -> Map
}

public extension PersistQueryExecution {
    func execute(id: Id, rootValue: Any = Void(), contextValue: Any = Void(), variableValues: [String: Map] = [:], operationName: String? = nil) throws -> Map {
        return try execute(id: id, rootValue: rootValue, contextValue: contextValue, variableValues: variableValues, operationName: operationName)
    }
}
