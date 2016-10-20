/**
 * A GraphQLError describes an Error found during the parse, validate, or
 * execute phases of performing a GraphQL operation. In addition to a message
 * and stack trace, it also includes information about the locations in a
 * GraphQL document and/or execution result that correspond to the Error.
 */
public struct GraphQLError : Error {

    /**
     * A message describing the Error for debugging purposes.
     *
     * Enumerable, and appears in the result of JSON.stringify().
     */
    let message: String

    /**
     * An array of { line, column } locations within the source GraphQL document
     * which correspond to this error.
     *
     * Errors during validation often contain multiple locations, for example to
     * point out two things with the same name. Errors during execution include a
     * single location, the field which produced the error.
     *
     * Enumerable, and appears in the result of JSON.stringify().
     */
    let locations: [SourceLocation]

    /**
     * An array describing the JSON-path into the execution response which
     * corresponds to this error. Only included for errors during execution.
     *
     * Enumerable, and appears in the result of JSON.stringify().
     */
    let path: [IndexPathElement]

    /**
     * An array of GraphQL AST Nodes corresponding to this error.
     */
    let nodes: [Node]

    /**
     * The source GraphQL document corresponding to this error.
     */
    let source: Source?

    /**
     * An array of character offsets within the source GraphQL document
     * which correspond to this error.
     */
    let positions: [Int]

    /**
     * The original error thrown from a field resolver during execution.
     */
    let originalError: Error?

    public init(message: String, nodes: [Node] = [], source: Source? = nil, positions: [Int] = [],
                path: [IndexPathElement] = [], originalError: Error? = nil) {
        self.message = message
        self.nodes = nodes

        if let source = source {
            self.source = source
        } else if !nodes.isEmpty {
            self.source = nodes[0].loc?.source
        } else {
            self.source = nil
        }

        if positions.isEmpty && !nodes.isEmpty {
            self.positions = nodes.filter({ $0.loc != nil }).map({ $0.loc!.start })
        } else {
            self.positions = positions
        }

        if let source = source, !positions.isEmpty {
            self.locations = positions.map({ getLocation(source: source, position: $0) })
        } else {
            self.locations = []
        }

        self.path = path
        self.originalError = originalError
    }
}

extension GraphQLError : CustomStringConvertible {
    public var description: String {
        return message
    }
}

extension GraphQLError : Equatable {
    public var hashValue: Int {
        return message.hashValue
    }
}

public func == (lhs: GraphQLError, rhs: GraphQLError) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension GraphQLError : MapRepresentable {
    public var map: Map {
        var dictionary: [String: Map] = ["message": message.map]

        if !path.isEmpty {
            dictionary["path"] = path.map({ $0.map }).map
        }

        return .dictionary(dictionary)
    }
}
