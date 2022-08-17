public class AnyEncodable : Encodable {
    private let encodable: Encodable
    
    public init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    
    public func encode(to encoder: Encoder) throws {
        return try self.encodable.encode(to: encoder)
    }
}

public class AnyCodable : Codable {
    private let codable: Codable
    
    public init(_ codable: Codable) {
        self.codable = codable
    }
    
    public func encode(to encoder: Encoder) throws {
        return try self.codable.encode(to: encoder)
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.codable = "Null"
        } else if let bool = try? container.decode(Bool.self) {
            self.codable = bool
        } else if let int = try? container.decode(Int.self) {
            self.codable = int
        } else if let uint = try? container.decode(UInt.self) {
            self.codable = uint
        } else if let double = try? container.decode(Double.self) {
            self.codable = double
        } else if let string = try? container.decode(String.self) {
            self.codable = string
        } else if let array = try? container.decode([AnyCodable].self) {
            codable = array
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            codable = dictionary
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable: can't decode value")
        }
    }
}
