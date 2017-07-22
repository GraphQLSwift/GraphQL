
public enum PersistedQueryRetrievalResult<T> {
    case unknownId(T)
    case parseError(GraphQLError)
    case validateErrors(GraphQLSchema, [GraphQLError])
    case result(GraphQLSchema, Document)
}

public protocol PersistedQueryRetrieval {
    associatedtype Id
    func lookup(_ id: Id) throws -> PersistedQueryRetrievalResult<Id>
}
