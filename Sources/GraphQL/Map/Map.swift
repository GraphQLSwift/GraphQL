public enum Map {
    case null
    case bool(Bool)
    case double(Double)
    case int(Int)
    case string(String)
    case array([Map])
    case dictionary([String: Map])
}

public protocol MapInitializable {
    init(map: Map) throws
}

public protocol MapRepresentable : MapFallibleRepresentable {
    var map: Map { get }
}

public protocol MapFallibleRepresentable {
    func asMap() throws -> Map
}

extension MapRepresentable {
    public func asMap() throws -> Map {
        return map
    }
}

public protocol MapConvertible : MapInitializable, MapFallibleRepresentable {}

// MARK: MapError

public enum MapError : Error {
    case incompatibleType
    case outOfBounds
    case valueNotFound
    case notMapInitializable(Any.Type)
    case notMapRepresentable(Any.Type)
    case notMapDictionaryKeyInitializable(Any.Type)
    case notMapDictionaryKeyRepresentable(Any.Type)
    case cannotInitialize(type: Any.Type, from: Any.Type)
}

// MARK: Parser/Serializer Protocols

public enum MapParserError : Error {
    case invalidInput
}

// MARK: Initializers

extension Map {
    public init<T: MapRepresentable>(_ value: T?) {
        self = value?.map ?? .null
    }

    public init<T: MapRepresentable>(_ values: [T]?) {
        if let values = values {
            self = .array(values.map({$0.map}))
        } else {
            self = .null
        }
    }

    public init<T: MapRepresentable>(_ values: [T?]?) {
        if let values = values {
            self = .array(values.map({$0?.map ?? .null}))
        } else {
            self = .null
        }
    }

    public init<T: MapRepresentable>(_ values: [String: T]?) {
        if let values = values {
            var dictionary: [String: Map] = [:]

            for (key, value) in values.map({($0.key, $0.value.map)}) {
                dictionary[key] = value
            }

            self = .dictionary(dictionary)
        } else {
            self = .null
        }
    }

    public init<T: MapRepresentable>(_ values: [String: T?]?) {
        if let values = values {
            var dictionary: [String: Map] = [:]

            for (key, value) in values.map({($0.key, $0.value?.map ?? .null)}) {
                dictionary[key] = value
            }

            self = .dictionary(dictionary)
        } else {
            self = .null
        }
    }
}

// MARK: is<Type>

extension Map {
    public var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    public var isBool: Bool {
        if case .bool = self {
            return true
        }
        return false
    }

    public var isDouble: Bool {
        if case .double = self {
            return true
        }
        return false
    }

    public var isInt: Bool {
        if case .int = self {
            return true
        }
        return false
    }

    public var isString: Bool {
        if case .string = self {
            return true
        }
        return false
    }

    public var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }

    public var isDictionary: Bool {
        if case .dictionary = self {
            return true
        }
        return false
    }
}

// MARK: as<type>?

extension Map {
    public var bool: Bool? {
        return try? get()
    }

    public var double: Double? {
        return try? get()
    }

    public var int: Int? {
        return try? get()
    }

    public var string: String? {
        return try? get()
    }

    public var array: [Map]? {
        return try? get()
    }

    public var dictionary: [String: Map]? {
        return try? get()
    }
}

// MARK: try as<type>()

extension Map {
    public func asBool(converting: Bool = false) throws -> Bool {
        guard converting else {
            return try get()
        }

        switch self {
        case .bool(let value):
            return value

        case .int(let value):
            return value != 0

        case .double(let value):
            return value != 0

        case .string(let value):
            switch value.lowercased() {
            case "true": return true
            case "false": return false
            default: throw MapError.incompatibleType
            }

        case .array(let value):
            return !value.isEmpty

        case .dictionary(let value):
            return !value.isEmpty

        case .null:
            return false
        }
    }

    public func asInt(converting: Bool = false) throws -> Int {
        guard converting else {
            return try get()
        }

        switch self {
        case .bool(let value):
            return value ? 1 : 0

        case .int(let value):
            return value

        case .double(let value):
            return Int(value)

        case .string(let value):
            if let int = Int(value) {
                return int
            }
            throw MapError.incompatibleType

        case .null:
            return 0

        default:
            throw MapError.incompatibleType
        }
    }

    public func asDouble(converting: Bool = false) throws -> Double {
        guard converting else {
            return try get()
        }

        switch self {
        case .bool(let value):
            return value ? 1.0 : 0.0

        case .int(let value):
            return Double(value)

        case .double(let value):
            return value

        case .string(let value):
            if let double = Double(value) {
                return double
            }
            throw MapError.incompatibleType

        case .null:
            return 0

        default:
            throw MapError.incompatibleType
        }
    }

    public func asString(converting: Bool = false) throws -> String {
        guard converting else {
            return try get()
        }

        switch self {
        case .bool(let value):
            return String(value)

        case .int(let value):
            return String(value)

        case .double(let value):
            return String(value)

        case .string(let value):
            return value

        case .array:
            throw MapError.incompatibleType

        case .dictionary:
            throw MapError.incompatibleType

        case .null:
            return "null"
        }
    }

    public func asArray(converting: Bool = false) throws -> [Map] {
        guard converting else {
            return try get()
        }

        switch self {
        case .array(let value):
            return value

        case .null:
            return []

        default:
            throw MapError.incompatibleType
        }
    }

    public func asDictionary(converting: Bool = false) throws -> [String: Map] {
        guard converting else {
            return try get()
        }

        switch self {
        case .dictionary(let value):
            return value

        case .null:
            return [:]

        default:
            throw MapError.incompatibleType
        }
    }
}

// MARK: IndexPath

public typealias IndexPath = [IndexPathElement]

public enum IndexPathValue {
    case index(Int)
    case key(String)
}

public protocol IndexPathElement : MapRepresentable {
    var indexPathValue: IndexPathValue { get }
}

extension IndexPathElement {
    public var map: Map {
        switch indexPathValue {
        case .index(let index): return index.map
        case .key(let key): return key.map
        }
    }
}

extension IndexPathElement {
    public var indexValue: Int? {
        if case .index(let index) = indexPathValue {
            return index
        }
        return nil
    }

    public var keyValue: String? {
        if case .key(let key) = indexPathValue {
            return key
        }
        return nil
    }
}

extension IndexPathElement {
    var constructEmptyContainer: Map {
        switch indexPathValue {
        case .index: return []
        case .key: return [:]
        }
    }
}

extension Int : IndexPathElement {
    public var indexPathValue: IndexPathValue {
        return .index(self)
    }
}

extension String : IndexPathElement {
    public var indexPathValue: IndexPathValue {
        return .key(self)
    }
}

// MARK: Get

extension Map {
    public func get<T : MapInitializable>(_ indexPath: IndexPathElement...) throws -> T {
        let map = try get(indexPath)
        return try T(map: map)
    }

    public func get<T>(_ indexPath: IndexPathElement...) throws -> T {
        if indexPath.isEmpty {
            switch self {
            case .bool(let value as T): return value
            case .int(let value as T): return value
            case .double(let value as T): return value
            case .string(let value as T): return value
            case .array(let value as T): return value
            case .dictionary(let value as T): return value
            default: throw MapError.incompatibleType
            }
        }
        return try get(indexPath).get()
    }

    public func get(_ indexPath: IndexPathElement...) throws -> Map {
        return try get(indexPath)
    }

    public func get(_ indexPath: IndexPath) throws -> Map {
        var value: Map = self

        for element in indexPath {
            switch element.indexPathValue {
            case .index(let index):
                let array = try value.asArray()
                if array.indices.contains(index) {
                    value = array[index]
                } else {
                    throw MapError.outOfBounds
                }

            case .key(let key):
                let dictionary = try value.asDictionary()
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

extension Map {
    public mutating func set<T : MapRepresentable>(_ value: T, for indexPath: IndexPathElement...) throws {
        try set(value, for: indexPath)
    }

    public mutating func set<T : MapRepresentable>(_ value: T, for indexPath: [IndexPathElement]) throws {
        try set(value, for: indexPath, merging: true)
    }

    fileprivate mutating func set<T : MapRepresentable>(_ value: T, for indexPath: [IndexPathElement], merging: Bool) throws {
        var indexPath = indexPath

        guard let first = indexPath.first else {
            return self = value.map
        }

        indexPath.removeFirst()

        if indexPath.isEmpty {
            switch first.indexPathValue {
            case .index(let index):
                if case .array(var array) = self {
                    if !array.indices.contains(index) {
                        throw MapError.outOfBounds
                    }
                    array[index] = value.map
                    self = .array(array)
                } else {
                    throw MapError.incompatibleType
                }
            case .key(let key):
                if case .dictionary(var dictionary) = self {
                    let newValue = value.map
                    if let existingDictionary = dictionary[key]?.dictionary,
                        let newDictionary = newValue.dictionary,
                        merging {
                        var combinedDictionary: [String: Map] = [:]

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
            var next = (try? self.get(first)) ?? first.constructEmptyContainer
            try next.set(value, for: indexPath)
            try self.set(next, for: [first])
        }
    }
}

// MARK: Remove

extension Map {
    public mutating func remove(_ indexPath: IndexPathElement...) throws {
        try self.remove(indexPath)
    }

    public mutating func remove(_ indexPath: [IndexPathElement]) throws {
        var indexPath = indexPath

        guard let first = indexPath.first else {
            return self = .null
        }

        indexPath.removeFirst()

        if indexPath.isEmpty {
            guard case .dictionary(var dictionary) = self, case .key(let key) = first.indexPathValue else {
                throw MapError.incompatibleType
            }

            dictionary[key] = nil
            self = .dictionary(dictionary)
        } else {
            guard var next = try? self.get(first) else {
                throw MapError.valueNotFound
            }
            try next.remove(indexPath)
            try self.set(next, for: [first], merging: false)
        }
    }
}

// MARK: Subscripts

extension Map {
    public subscript(indexPath: IndexPathElement...) -> Map {
        get {
            return self[indexPath]
        }

        set(value) {
            self[indexPath] = value
        }
    }

    public subscript(indexPath: [IndexPathElement]) -> Map {
        get {
            return (try? self.get(indexPath)) ?? nil
        }

        set(value) {
            do {
                try self.set(value, for: indexPath)
            } catch {
                fatalError(String(describing: error))
            }
        }
    }
}

// MARK: Equatable

extension Map : Equatable {}

public func == (lhs: Map, rhs: Map) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null): return true
    case let (.int(l), .int(r)) where l == r: return true
    case let (.bool(l), .bool(r)) where l == r: return true
    case let (.string(l), .string(r)) where l == r: return true
    case let (.double(l), .double(r)) where l == r: return true
    case let (.array(l), .array(r)) where l == r: return true
    case let (.dictionary(l), .dictionary(r)) where l == r: return true
    default: return false
    }
}

// MARK: Hashable

extension Map : Hashable {
    public var hashValue: Int {
        switch self {
        case .null:
            return 0
        case .bool(let bool):
            return bool.hashValue
        case .double(let double):
            return double.hashValue
        case .int(let int):
            return int.hashValue
        case .string(let string):
            return string.hashValue
        case .array(let array):
            var hash = 5381

            for item in array {
                hash = ((hash << 5) &+ hash) &+ item.hashValue
            }

            return hash
        case .dictionary(let dictionary):
            var hash = 5381
            var keyHash = 5381
            var valueHash = 5381

            for (key, value) in dictionary {
                keyHash = ((keyHash << 5) &+ keyHash) &+ key.hashValue
                valueHash = ((valueHash << 5) &+ valueHash) &+ value.hashValue
                hash = ((hash << 5) &+ hash) &+ (keyHash ^ valueHash)
            }

            return hash
        }
    }
}

// MARK: Literal Convertibles

extension Map : ExpressibleByNilLiteral {
    public init(nilLiteral value: Void) {
        self = .null
    }
}

extension Map : ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension Map : ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
}

extension Map : ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}

extension Map : ExpressibleByStringLiteral {
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

extension Map : ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Map...) {
        self = .array(elements)
    }
}

extension Map : ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Map)...) {
        var dictionary = [String: Map](minimumCapacity: elements.count)
        
        for (key, value) in elements {
            dictionary[key] = value
        }
        
        self = .dictionary(dictionary)
    }
}
