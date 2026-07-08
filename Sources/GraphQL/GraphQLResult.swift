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

/// A collection of GraphQL errors. Enables returning multiple errors from Result types.
public struct GraphQLErrors: Error, Sendable {
    public let errors: [GraphQLError]

    public init(_ errors: [GraphQLError]) {
        self.errors = errors
    }
}
