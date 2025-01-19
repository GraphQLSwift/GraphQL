@preconcurrency import Foundation

public struct Number: Sendable {
    public enum StorageType: Sendable {
        case bool
        case int
        case double
        case unknown
    }

    private var _number: NSNumber
    public var storageType: StorageType

    public var number: NSNumber {
        mutating get {
            if !isKnownUniquelyReferenced(&_number) {
                _number = _number.copy() as! NSNumber
            }

            return _number
        }

        set {
            _number = newValue
        }
    }

    public init(_ value: NSNumber) {
        _number = value
        storageType = .unknown
    }

    public init(_ value: Bool) {
        _number = NSNumber(value: value)
        storageType = .bool
    }

    @available(OSX 10.5, *)
    public init(_ value: Int) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    @available(OSX 10.5, *)
    public init(_ value: UInt) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: Int8) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: UInt8) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: Int16) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: UInt16) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: Int32) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: UInt32) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: Int64) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: UInt64) {
        _number = NSNumber(value: value)
        storageType = .int
    }

    public init(_ value: Float) {
        _number = NSNumber(value: value)
        storageType = .double
    }

    public init(_ value: Double) {
        _number = NSNumber(value: value)
        storageType = .double
    }

    public var boolValue: Bool {
        return _number.boolValue
    }

    @available(OSX 10.5, *)
    public var intValue: Int {
        return _number.intValue
    }

    @available(OSX 10.5, *)
    public var uintValue: UInt {
        return _number.uintValue
    }

    public var int8Value: Int8 {
        return _number.int8Value
    }

    public var uint8Value: UInt8 {
        return _number.uint8Value
    }

    public var int16Value: Int16 {
        return _number.int16Value
    }

    public var uint16Value: UInt16 {
        return _number.uint16Value
    }

    public var int32Value: Int32 {
        return _number.int32Value
    }

    public var uint32Value: UInt32 {
        return _number.uint32Value
    }

    public var int64Value: Int64 {
        return _number.int64Value
    }

    public var uint64Value: UInt64 {
        return _number.uint64Value
    }

    public var floatValue: Float {
        return _number.floatValue
    }

    public var doubleValue: Double {
        return _number.doubleValue
    }

    public var stringValue: String {
        return _number.stringValue
    }
}

extension Number: Hashable {}

extension Number: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs._number == rhs._number
    }
}

extension Number: Comparable {
    public static func < (lhs: Number, rhs: Number) -> Bool {
        return lhs._number.compare(rhs._number) == .orderedAscending
    }
}

extension Number: ExpressibleByBooleanLiteral {
    /// Create an instance initialized to `value`.
    public init(booleanLiteral value: Bool) {
        _number = NSNumber(value: value)
        storageType = .bool
    }
}

extension Number: ExpressibleByIntegerLiteral {
    /// Create an instance initialized to `value`.
    public init(integerLiteral value: Int) {
        _number = NSNumber(value: value)
        storageType = .int
    }
}

extension Number: ExpressibleByFloatLiteral {
    /// Create an instance initialized to `value`.
    public init(floatLiteral value: Double) {
        _number = NSNumber(value: value)
        storageType = .double
    }
}

extension Number: CustomStringConvertible {
    public var description: String {
        return _number.description
    }
}
