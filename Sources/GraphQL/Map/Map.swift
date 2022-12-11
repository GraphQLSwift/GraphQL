import Foundation
import OrderedCollections

// MARK: MapError

public enum MapError: Error {
    case incompatibleType
    case outOfBounds
    case valueNotFound
}

// MARK: Map

public enum Map {
    case undefined
    case null
    case bool(Bool)
    case number(Number)
    case string(String)
    case array([Map])
    case dictionary(OrderedDictionary<String, Map>)

    public static func int(_ value: Int) -> Map {
        return .number(Number(value))
    }

    public static func double(_ value: Double) -> Map {
        return .number(Number(value))
    }
}

// MARK: Initializers

public extension Map {
    static let encoder = MapEncoder()

    init<T: Encodable>(_ encodable: T, encoder: MapEncoder = Map.encoder) throws {
        self = try encoder.encode(encodable)
    }

    init(_ number: Number) {
        self = .number(number)
    }

    init(_ bool: Bool) {
        self = .bool(bool)
    }

    init(_ int: Int) {
        self.init(Number(int))
    }

    init(_ double: Double) {
        self.init(Number(double))
    }

    init(_ string: String) {
        self = .string(string)
    }

    init(_ array: [Map]) {
        self = .array(array)
    }

    init(_ dictionary: OrderedDictionary<String, Map>) {
        self = .dictionary(dictionary)
    }

    init(_ number: Number?) {
        self = number.map { Map($0) } ?? .null
    }

    init(_ bool: Bool?) {
        self.init(bool.map { Number($0) })
    }

    init(_ int: Int?) {
        self.init(int.map { Number($0) })
    }

    init(_ double: Double?) {
        self.init(double.map { Number($0) })
    }

    init(_ string: String?) {
        self = string.map { Map($0) } ?? .null
    }

    init(_ array: [Map]?) {
        self = array.map { Map($0) } ?? .null
    }

    init(_ dictionary: OrderedDictionary<String, Map>?) {
        self = dictionary.map { Map($0) } ?? .null
    }
}

// MARK: Any

public func map(from value: Any?) throws -> Map {
    guard let value = value else {
        return .null
    }

    if let map = value as? Map {
        return map
    }

    if let map = try? Map(any: value) {
        return map
    }

    if
        let value = value as? OrderedDictionary<String, Any>,
        let dictionary: OrderedDictionary<String, Map> = try? value
            .reduce(into: [:], { result, pair in
                result[pair.key] = try map(from: pair.value)
            })
    {
        return .dictionary(dictionary)
    }

    if
        let value = value as? [Any],
        let array: [Map] = try? value.map({ value in
            try map(from: value)
        })
    {
        return .array(array)
    }

    if
        let value = value as? Encodable,
        let map = try? Map(AnyEncodable(value))
    {
        return map
    }

    throw MapError.incompatibleType
}

public extension Map {
    init(any: Any?) throws {
        switch any {
        case .none:
            self = .null
        case let number as Number:
            self = .number(number)
        case let bool as Bool:
            self = .bool(bool)
        case let double as Double:
            self = .number(Number(double))
        case let int as Int:
            self = .number(Number(int))
        case let string as String:
            self = .string(string)
        case let array as [Map]:
            self = .array(array)
        case let dictionary as OrderedDictionary<String, Map>:
            self = .dictionary(dictionary)
        default:
            throw MapError.incompatibleType
        }
    }
}

// MARK: is<Type>

public extension Map {
    var isUndefined: Bool {
        if case .undefined = self {
            return true
        }
        return false
    }

    var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    var isNumber: Bool {
        if case .number = self {
            return true
        }
        return false
    }

    var isString: Bool {
        if case .string = self {
            return true
        }
        return false
    }

    var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }

    var isDictionary: Bool {
        if case .dictionary = self {
            return true
        }
        return false
    }
}

// MARK: is<Type>

public extension Map {
    var typeDescription: String {
        switch self {
        case .undefined:
            return "undefined"
        case .null:
            return "null"
        case .bool:
            return "bool"
        case .number:
            return "number"
        case .string:
            return "string"
        case .array:
            return "array"
        case .dictionary:
            return "dictionary"
        }
    }
}

// MARK: as<type>?

public extension Map {
    var bool: Bool? {
        return try? boolValue()
    }

    var int: Int? {
        return try? intValue()
    }

    var double: Double? {
        return try? doubleValue()
    }

    var string: String? {
        return try? stringValue()
    }

    var array: [Map]? {
        return try? arrayValue()
    }

    var dictionary: OrderedDictionary<String, Map>? {
        return try? dictionaryValue()
    }
}

// MARK: try as<type>()

public extension Map {
    func boolValue(converting: Bool = false) throws -> Bool {
        guard converting else {
            return try get()
        }

        switch self {
        case .undefined:
            return false

        case .null:
            return false

        case let .bool(value):
            return value

        case let .number(number):
            return number.boolValue

        case let .string(value):
            switch value.lowercased() {
            case "true": return true
            case "false": return false
            default: throw MapError.incompatibleType
            }

        case let .array(value):
            return !value.isEmpty

        case let .dictionary(value):
            return !value.isEmpty
        }
    }

    func intValue(converting: Bool = false) throws -> Int {
        guard converting else {
            return try (get() as Number).intValue
        }

        switch self {
        case .null:
            return 0

        case let .number(number):
            return number.intValue

        case let .string(value):
            guard let value = Int(value) else {
                throw MapError.incompatibleType
            }

            return value

        default:
            throw MapError.incompatibleType
        }
    }

    func doubleValue(converting: Bool = false) throws -> Double {
        guard converting else {
            return try (get() as Number).doubleValue
        }

        switch self {
        case .null:
            return 0

        case let .number(number):
            return number.doubleValue

        case let .string(value):
            guard let value = Double(value) else {
                throw MapError.incompatibleType
            }

            return value

        default:
            throw MapError.incompatibleType
        }
    }

    func stringValue(converting: Bool = false) throws -> String {
        guard converting else {
            return try get()
        }

        switch self {
        case .undefined:
            return "undefined"

        case .null:
            return "null"

        case let .bool(value):
            return "\(value)"

        case let .number(number):
            return number.stringValue

        case let .string(value):
            return value

        case .array:
            throw MapError.incompatibleType

        case .dictionary:
            throw MapError.incompatibleType
        }
    }

    func arrayValue(converting: Bool = false) throws -> [Map] {
        guard converting else {
            return try get()
        }

        switch self {
        case let .array(value):
            return value

        case .null:
            return []

        default:
            throw MapError.incompatibleType
        }
    }

    func dictionaryValue(converting: Bool = false) throws -> OrderedDictionary<String, Map> {
        guard converting else {
            return try get()
        }

        switch self {
        case let .dictionary(value):
            return value

        case .null:
            return [:]

        default:
            throw MapError.incompatibleType
        }
    }
}

// MARK: Get

public extension Map {
    func get<T>(_ indexPath: IndexPathElement...) throws -> T {
        if indexPath.isEmpty {
            switch self {
            case let .number(value as T):
                return value
            case let .bool(value as T):
                return value
            case let .string(value as T):
                return value
            case let .array(value as T):
                return value
            case let .dictionary(value as T):
                return value
            default:
                throw MapError.incompatibleType
            }
        }

        return try get(IndexPath(indexPath)).get()
    }

    func get(_ indexPath: IndexPathElement...) throws -> Map {
        return try get(IndexPath(indexPath))
    }

    func get(_ indexPath: IndexPath) throws -> Map {
        var value: Map = self

        for element in indexPath.elements {
            switch element {
            case let .index(index):
                let array = try value.arrayValue()

                if array.indices.contains(index) {
                    value = array[index]
                } else {
                    throw MapError.outOfBounds
                }

            case let .key(key):
                let dictionary = try value.dictionaryValue()

                if let newValue = dictionary[key] {
                    value = newValue
                } else {
                    throw MapError.valueNotFound
                }
            }
        }

        return value
    }
}

// MARK: Set

public extension Map {
    mutating func set(_ value: Map, for indexPath: IndexPathElement...) throws {
        try set(value, for: indexPath)
    }

    mutating func set(_ value: Map, for indexPath: [IndexPathElement]) throws {
        try set(value, for: IndexPath(indexPath), merging: true)
    }

    fileprivate mutating func set(_ value: Map, for indexPath: IndexPath, merging: Bool) throws {
        var elements = indexPath.elements

        guard let first = elements.first else {
            return self = value
        }

        elements.removeFirst()

        if elements.isEmpty {
            switch first {
            case let .index(index):
                if case var .array(array) = self {
                    if !array.indices.contains(index) {
                        throw MapError.outOfBounds
                    }

                    array[index] = value
                    self = .array(array)
                } else {
                    throw MapError.incompatibleType
                }
            case let .key(key):
                if case var .dictionary(dictionary) = self {
                    let newValue = value

                    if
                        let existingDictionary = dictionary[key]?.dictionary,
                        let newDictionary = newValue.dictionary,
                        merging
                    {
                        var combinedDictionary: OrderedDictionary<String, Map> = [:]

                        for (key, value) in existingDictionary {
                            combinedDictionary[key] = value
                        }

                        for (key, value) in newDictionary {
                            combinedDictionary[key] = value
                        }

                        dictionary[key] = .dictionary(combinedDictionary)
                    } else {
                        dictionary[key] = newValue
                    }

                    self = .dictionary(dictionary)
                } else {
                    throw MapError.incompatibleType
                }
            }
        } else {
            var next = (try? get(first)) ?? first.constructEmptyContainer
            try next.set(value, for: indexPath, merging: true)
            try set(next, for: [first])
        }
    }
}

// MARK: Remove

public extension Map {
    mutating func remove(_ indexPath: IndexPathElement...) throws {
        try remove(indexPath)
    }

    mutating func remove(_ indexPath: [IndexPathElement]) throws {
        var indexPath = indexPath

        guard let first = indexPath.first else {
            return self = .null
        }

        indexPath.removeFirst()

        if indexPath.isEmpty {
            guard
                case var .dictionary(dictionary) = self,
                case let .key(key) = first.indexPathValue
            else {
                throw MapError.incompatibleType
            }

            dictionary[key] = nil
            self = .dictionary(dictionary)
        } else {
            guard var next = try? get(first) else {
                throw MapError.valueNotFound
            }
            try next.remove(indexPath)
            try set(next, for: [first], merging: false)
        }
    }
}

// MARK: Subscripts

public extension Map {
    subscript(indexPath: IndexPathElement...) -> Map {
        get {
            return self[IndexPath(indexPath)]
        }

        set(value) {
            self[IndexPath(indexPath)] = value
        }
    }

    subscript(indexPath: IndexPath) -> Map {
        get {
            return (try? get(indexPath)) ?? nil
        }

        set(value) {
            do {
                try set(value, for: indexPath, merging: true)
            } catch {
                fatalError(String(describing: error))
            }
        }
    }
}

extension String: CodingKey {
    public var stringValue: String {
        return self
    }

    public init?(stringValue: String) {
        self = stringValue
    }

    public var intValue: Int? {
        return nil
    }

    public init?(intValue _: Int) {
        return nil
    }
}

extension Map: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let double = try? container.decode(Double.self) {
            self = .number(Number(double))
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([Map].self) {
            self = .array(array)
        } else if let _ = try? container.decode([String: Map].self) {
            // Override OrderedDictionary default (unkeyed alternating key-value)
            // Instead decode as a keyed container (like normal Dictionary) but use the order of the
            // input
            let container = try decoder.container(keyedBy: _DictionaryCodingKey.self)
            var orderedDictionary: OrderedDictionary<String, Map> = [:]
            for key in container.allKeys {
                let value = try container.decode(Map.self, forKey: key)
                orderedDictionary[key.stringValue] = value
            }
            self = .dictionary(orderedDictionary)
        } else if let dictionary = try? container.decode(OrderedDictionary<String, Map>.self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Corrupted data"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .undefined:
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "undefined values should have been excluded from encoding"
                )
            )
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(number):
            try container.encode(number.doubleValue)
        case let .string(string):
            try container.encode(string)
        case let .array(array):
            try container.encode(array)
        case let .dictionary(dictionary):
            // Override OrderedDictionary default (unkeyed alternating key-value)
            // Instead decode as a keyed container (like normal Dictionary) in the order of our
            // OrderedDictionary
            // Note that `JSONEncoder` will ignore this because it uses `Dictionary` underneath.
            // Instead, use `GraphQLJSONEncoder`.
            var container = encoder.container(keyedBy: _DictionaryCodingKey.self)
            for (key, value) in dictionary {
                if !value.isUndefined {
                    guard let codingKey = _DictionaryCodingKey(stringValue: key) else {
                        throw EncodingError.invalidValue(
                            self,
                            EncodingError.Context(
                                codingPath: [],
                                debugDescription: "codingKey not found for dictionary key: \(key)"
                            )
                        )
                    }
                    try container.encode(value, forKey: codingKey)
                }
            }
        }
    }

    /// A wrapper for dictionary keys which are Strings or Ints.
    /// This is copied from Swift core: https://github.com/apple/swift/blob/256a9c5ad96378daa03fa2d5197b4201bf16db27/stdlib/public/core/Codable.swift#L5508
    internal struct _DictionaryCodingKey: CodingKey {
        internal let stringValue: String
        internal let intValue: Int?

        internal init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = Int(stringValue)
        }

        internal init?(intValue: Int) {
            stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}

// MARK: Equatable

extension Map: Equatable {}

public func == (lhs: Map, rhs: Map) -> Bool {
    switch (lhs, rhs) {
    case (.undefined, .undefined):
        return true
    case (.null, .null):
        return true
    case let (.bool(l), .bool(r)) where l == r:
        return true
    case let (.number(l), .number(r)) where l == r:
        return true
    case let (.string(l), .string(r)) where l == r:
        return true
    case let (.array(l), .array(r)) where l == r:
        return true
    case let (.dictionary(l), .dictionary(r)) where l == r:
        return true
    default:
        return false
    }
}

// MARK: Hashable

extension Map: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .undefined:
            hasher.combine(0)
        case .null:
            hasher.combine(0)
        case let .bool(value):
            hasher.combine(value)
        case let .number(number):
            hasher.combine(number)
        case let .string(string):
            hasher.combine(string)
        case let .array(array):
            hasher.combine(array)
        case let .dictionary(dictionary):
            hasher.combine(dictionary)
        }
    }
}

// MARK: Literal Convertibles

extension Map: ExpressibleByNilLiteral {
    public init(nilLiteral _: Void) {
        self = .null
    }
}

extension Map: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension Map: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(Number(value))
    }
}

extension Map: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(Number(value))
    }
}

extension Map: ExpressibleByStringLiteral {
    public init(unicodeScalarLiteral value: String) {
        self = .string(value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = .string(value)
    }

    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension Map: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Map...) {
        self = .array(elements)
    }
}

extension Map: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Map)...) {
        var dictionary = OrderedDictionary<String, Map>(minimumCapacity: elements.count)

        for (key, value) in elements {
            dictionary[key] = value
        }

        self = .dictionary(dictionary)
    }
}

// MARK: CustomStringConvertible

extension Map: CustomStringConvertible {
    public var description: String {
        return self.description(debug: false)
    }
}

// MARK: CustomDebugStringConvertible

extension Map: CustomDebugStringConvertible {
    public var debugDescription: String {
        return description(debug: true)
    }
}

// MARK: Generic Description

public extension Map {
    func description(debug: Bool) -> String {
        var indentLevel = 0

        let escapeMapping: [Character: String] = [
            "\r": "\\r",
            "\n": "\\n",
            "\t": "\\t",
            "\\": "\\\\",
            "\"": "\\\"",

            "\u{2028}": "\\u2028",
            "\u{2029}": "\\u2029",

            "\r\n": "\\r\\n",
        ]

        func escape(_ source: String) -> String {
            var string = "\""

            for character in source {
                if let escapedSymbol = escapeMapping[character] {
                    string.append(escapedSymbol)
                } else {
                    string.append(character)
                }
            }

            string.append("\"")
            return string
        }

        func serialize(map: Map) -> String {
            switch map {
            case .undefined:
                return "undefined"
            case .null:
                return "null"
            case let .bool(value):
                return value.description
            case let .number(number):
                return number.description
            case let .string(string):
                return escape(string)
            case let .array(array):
                return serialize(array: array)
            case let .dictionary(dictionary):
                return serialize(dictionary: dictionary)
            }
        }

        func serialize(array: [Map]) -> String {
            var string = "["

            if debug {
                indentLevel += 1
            }

            for index in 0 ..< array.count {
                if debug {
                    string += "\n"
                    string += indent()
                }

                string += serialize(map: array[index])

                if index != array.count - 1 {
                    if debug {
                        string += ", "
                    } else {
                        string += ","
                    }
                }
            }

            if debug {
                indentLevel -= 1
                return string + "\n" + indent() + "]"
            } else {
                return string + "]"
            }
        }

        func serialize(dictionary: OrderedDictionary<String, Map>) -> String {
            var string = "{"
            var index = 0

            if debug {
                indentLevel += 1
            }

            let filtered = dictionary.filter { item in
                !item.value.isUndefined
            }

            for (key, value) in filtered.sorted(by: { $0.0 < $1.0 }) {
                if debug {
                    string += "\n"
                    string += indent()
                    string += escape(key) + ": " + serialize(map: value)
                } else {
                    string += escape(key) + ":" + serialize(map: value)
                }

                if index != filtered.count - 1 {
                    if debug {
                        string += ", "
                    } else {
                        string += ","
                    }
                }

                index += 1
            }

            if debug {
                indentLevel -= 1
                return string + "\n" + indent() + "}"
            } else {
                return string + "}"
            }
        }

        func indent() -> String {
            return String(repeating: "    ", count: indentLevel)
        }

        return serialize(map: self)
    }
}
