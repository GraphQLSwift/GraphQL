/**
 * A GraphQLError describes an Error found during the parse, validate, or
 * execute phases of performing a GraphQL operation. In addition to a message
 * it also includes information about the locations in a
 * GraphQL document and/or execution result that correspond to the error.
 */
public struct GraphQLError: Error, Codable {
    enum CodingKeys: String, CodingKey {
        case message
        case locations
        case path
    }

    /**
     * A message describing the Error for debugging purposes.
     *
     * Appears in the result of `description`.
     */
    public let message: String

    /**
     * An array of (line: Int, column: Int) locations within the source GraphQL document
     * which correspond to this error.
     *
     * Errors during validation often contain multiple locations, for example to
     * point out two things with the same name. Errors during execution include a
     * single location, the field which produced the error.
     *
     * Appears in the result of `description`.
     */
    public let locations: [SourceLocation]

    /**
     * An array describing the index path into the execution response which
     * corresponds to this error. Only included for errors during execution.
     *
     * Appears in the result of `description`.
     */
    public let path: IndexPath

    /**
     * An array of GraphQL AST Nodes corresponding to this error.
     */
    public private(set) var nodes: [Node] = []

    /**
     * The source GraphQL document corresponding to this error.
     */
    public private(set) var source: Source? = nil

    /**
     * An array of character offsets within the source GraphQL document
     * which correspond to this error.
     */
    public private(set) var positions: [Int] = []

    /**
     * The original error thrown from a field resolver during execution.
     */
    public private(set) var originalError: Error? = nil

    public init(
        message: String,
        nodes: [Node] = [],
        source: Source? = nil,
        positions: [Int] = [],
        path: IndexPath = [],
        originalError: Error? = nil
    ) {
        self.message = message
        self.nodes = nodes

        if let source = source {
            self.source = source
        } else if !nodes.isEmpty {
            self.source = nodes[0].loc?.source
        } else {
            self.source = nil
        }

        if positions.isEmpty, !nodes.isEmpty {
            self.positions = nodes.filter { $0.loc != nil }.map { $0.loc!.start }
        } else {
            self.positions = positions
        }

        if let source = self.source, !self.positions.isEmpty {
            locations = self.positions.map { getLocation(source: source, position: $0) }
        } else {
            locations = []
        }

        self.path = path
        self.originalError = originalError
    }

    public init(
        message: String,
        locations: [SourceLocation],
        path: IndexPath = []
    ) {
        self.message = message
        self.locations = locations
        self.path = path
        nodes = []
        source = nil
        positions = []
        originalError = nil
    }

    public init(_ error: Error) {
        self.init(
            message: error.localizedDescription,
            originalError: error
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        locations = (try? container.decode([SourceLocation]?.self, forKey: .locations)) ?? []
        path = try container.decode(IndexPath.self, forKey: .path)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(message, forKey: .message)

        if !locations.isEmpty {
            try container.encode(locations, forKey: .locations)
        }

        try container.encode(path, forKey: .path)
    }
}

extension GraphQLError: CustomStringConvertible {
    public var description: String {
        return message
    }
}

extension GraphQLError: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(message)
    }

    public static func == (lhs: GraphQLError, rhs: GraphQLError) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

// MARK: IndexPath

public struct IndexPath: Codable {
    public let elements: [IndexPathValue]

    public init(_ elements: [IndexPathElement] = []) {
        self.elements = elements.map { $0.indexPathValue }
    }

    public func appending(_ elements: IndexPathElement) -> IndexPath {
        return IndexPath(self.elements + [elements])
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        elements = (try? container.decode([IndexPathValue].self)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(contentsOf: elements)
    }
}

extension IndexPath: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: IndexPathElement...) {
        self.elements = elements.map { $0.indexPathValue }
    }
}

public enum IndexPathValue: Codable {
    case index(Int)
    case key(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let index = try? container.decode(Int.self) {
            self = .index(index)
        } else if let key = try? container.decode(String.self) {
            self = .key(key)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid type.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .index(index):
            try container.encode(index)
        case let .key(key):
            try container.encode(key)
        }
    }
}

extension IndexPathValue: IndexPathElement {
    public var indexPathValue: IndexPathValue {
        return self
    }
}

extension IndexPathValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .index(index):
            return index.description
        case let .key(key):
            return key.description
        }
    }
}

public protocol IndexPathElement {
    var indexPathValue: IndexPathValue { get }
}

extension IndexPathElement {
    var constructEmptyContainer: Map {
        switch indexPathValue {
        case .index: return []
        case .key: return [:]
        }
    }
}

public extension IndexPathElement {
    var indexValue: Int? {
        if case let .index(index) = indexPathValue {
            return index
        }
        return nil
    }

    var keyValue: String? {
        if case let .key(key) = indexPathValue {
            return key
        }
        return nil
    }
}

extension Int: IndexPathElement {
    public var indexPathValue: IndexPathValue {
        return .index(self)
    }
}

extension String: IndexPathElement {
    public var indexPathValue: IndexPathValue {
        return .key(self)
    }
}
