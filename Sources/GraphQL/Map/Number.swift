import Foundation

public struct Number {
    public enum StorageType {
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
        self._number = value
        self.storageType = .unknown
    }
    
    public init(_ value: Bool) {
        self._number = NSNumber(value: value)
        self.storageType = .bool
    }
    
    @available(OSX 10.5, *)
    public init(_ value: Int) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }
    
    @available(OSX 10.5, *)
    public init(_ value: UInt) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: Int8) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: UInt8) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: Int16) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: UInt16) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: Int32) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: UInt32) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: Int64) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: UInt64) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }

    public init(_ value: Float) {
        self._number = NSNumber(value: value)
        self.storageType = .double
    }

    public init(_ value: Double) {
        self._number = NSNumber(value: value)
        self.storageType = .double
    }

    public var boolValue: Bool {
        return self._number.boolValue
    }
    
    @available(OSX 10.5, *)
    public var intValue: Int {
        return self._number.intValue
    }
    
    @available(OSX 10.5, *)
    public var uintValue: UInt {
        return self._number.uintValue
    }
    
    public var int8Value: Int8 {
        return self._number.int8Value
    }

    public var uint8Value: UInt8 {
        return self._number.uint8Value
    }

    public var int16Value: Int16 {
        return self._number.int16Value
    }

    public var uint16Value: UInt16 {
        return self._number.uint16Value
    }

    public var int32Value: Int32 {
        return self._number.int32Value
    }

    public var uint32Value: UInt32 {
        return self._number.uint32Value
    }

    public var int64Value: Int64 {
        return self._number.int64Value
    }

    public var uint64Value: UInt64 {
        return self._number.uint64Value
    }

    public var floatValue: Float {
        return self._number.floatValue
    }

    public var doubleValue: Double {
        return self._number.doubleValue
    }

    public var stringValue: String {
        return self._number.stringValue
    }
}

extension Number : Hashable {}
extension Number : Equatable {}

extension Number : Comparable {
    public static func < (lhs: Number, rhs: Number) -> Bool {
        return lhs._number.compare(rhs._number) == .orderedAscending
    }
}

extension Number : ExpressibleByBooleanLiteral {
    /// Create an instance initialized to `value`.
    public init(booleanLiteral value: Bool) {
        self._number = NSNumber(value: value)
        self.storageType = .bool
    }
}

extension Number : ExpressibleByIntegerLiteral {
    /// Create an instance initialized to `value`.
    public init(integerLiteral value: Int) {
        self._number = NSNumber(value: value)
        self.storageType = .int
    }
}

extension Number : ExpressibleByFloatLiteral {
    /// Create an instance initialized to `value`.
    public init(floatLiteral value: Double) {
        self._number = NSNumber(value: value)
        self.storageType = .double
    }
}

extension Number : CustomStringConvertible {
    public var description: String {
        return self._number.description
    }
}
