/**
 * A representation of source input to GraphQL. The name is optional,
 * but is mostly useful for clients who store GraphQL documents in
 * source files; for example, if the GraphQL input is in a file Foo.graphql,
 * it might be useful for name to be "Foo.graphql".
 *
 * Note that since Source parsing is heavily UTF8 dependent, the body
 * is converted into contiguous UTF8 bytes if necessary for optimal performance.
 */
public struct Source {
    public let body: String
    public let name: String

    public init(body: String, name: String = "GraphQL") {
        var utf8Body = body
        utf8Body.makeContiguousUTF8()

        self.body = utf8Body
        self.name = name
    }
}

extension Source: Equatable {
    public static func == (lhs: Source, rhs: Source) -> Bool {
        return lhs.body == rhs.body &&
            lhs.name == rhs.name
    }
}
