// swiftformat:disable all
import CoreFoundation
import Foundation

/// A marker protocol used to determine whether a value is a `String`-keyed `Dictionary`
/// containing `Encodable` values (in which case it should be exempt from key conversion strategies).
///
private protocol _AnyStringDictionaryEncodableMarker {}

extension Dictionary: _AnyStringDictionaryEncodableMarker where Key == String, Value: Encodable {}

/// A marker protocol used to determine whether a value is a `String`-keyed `Dictionary`
/// containing `Decodable` values (in which case it should be exempt from key conversion strategies).
///
/// The marker protocol also provides access to the type of the `Decodable` values,
/// which is needed for the implementation of the key conversion strategy exemption.
///
private protocol _AnyStringDictionaryDecodableMarker {
    static var elementType: Decodable.Type { get }
}

//===----------------------------------------------------------------------===//
// Any Encoder
//===----------------------------------------------------------------------===//

/// `AnyEncoder` facilitates the encoding of `Encodable` values into Any.
open class AnyEncoder {
    // MARK: Options

    /// The formatting of the output Any data.
    public struct OutputFormatting: OptionSet {
        /// The format's default value.
        public let rawValue: UInt

        /// Creates an OutputFormatting value with the given raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Produce human-readable Any with indented output.
        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)

        /// Produce Any with dictionary keys sorted in lexicographic order.
        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        public static let sortedKeys = OutputFormatting(rawValue: 1 << 1)
    }

    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferredToDate

        /// Encode the `Date` as a UNIX timestamp (as a Any number).
        case secondsSince1970

        /// Encode the `Date` as UNIX millisecond timestamp (as a Any number).
        case millisecondsSince1970

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)

        /// Encode the `Date` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        case custom((Date, Encoder) throws -> Void)
    }

    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData

        /// Encoded the `Data` as a Base64-encoded string. This is the default strategy.
        case base64

        /// Encode the `Data` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        case custom((Data, Encoder) throws -> Void)
    }

    /// The strategy to use for non-Any-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatEncodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before encoding.
    public enum KeyEncodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys

        /// Convert from "camelCaseKeys" to "snake_case_keys" before writing a key to Any payload.
        ///
        /// Capital characters are determined by testing membership in `CharacterSet.uppercaseLetters` and `CharacterSet.lowercaseLetters` (Unicode General Categories Lu and Lt).
        /// The conversion to lower case uses `Locale.system`, also known as the ICU "root" locale. This means the result is consistent regardless of the current user's locale and language preferences.
        ///
        /// Converting from camel case to snake case:
        /// 1. Splits words at the boundary of lower-case to upper-case
        /// 2. Inserts `_` between words
        /// 3. Lowercases the entire string
        /// 4. Preserves starting and ending `_`.
        ///
        /// For example, `oneTwoThree` becomes `one_two_three`. `_oneTwoThree_` becomes `_one_two_three_`.
        ///
        /// - Note: Using a key encoding strategy has a nominal performance cost, as each string key has to be converted.
        case convertToSnakeCase

        /// Provide a custom conversion to the key in the encoded Any from the keys specified by the encoded types.
        /// The full path to the current encoding position is provided for context (in case you need to locate this key within the payload). The returned key is used in place of the last component in the coding path before encoding.
        /// If the result of the conversion is a duplicate key, then only one value will be present in the result.
        case custom((_ codingPath: [CodingKey]) -> CodingKey)

        fileprivate static func _convertToSnakeCase(_ stringKey: String) -> String {
            guard !stringKey.isEmpty else { return stringKey }

            var words: [Range<String.Index>] = []
            // The general idea of this algorithm is to split words on transition from lower to upper case, then on transition of >1 upper case characters to lowercase
            //
            // myProperty -> my_property
            // myURLProperty -> my_url_property
            //
            // We assume, per Swift naming conventions, that the first character of the key is lowercase.
            var wordStart = stringKey.startIndex
            var searchRange = stringKey.index(after: wordStart) ..< stringKey.endIndex

            // Find next uppercase character
            while
                let upperCaseRange = stringKey.rangeOfCharacter(
                    from: CharacterSet.uppercaseLetters,
                    options: [],
                    range: searchRange
                )
            {
                let untilUpperCase = wordStart ..< upperCaseRange.lowerBound
                words.append(untilUpperCase)

                // Find next lowercase character
                searchRange = upperCaseRange.lowerBound ..< searchRange.upperBound
                guard
                    let lowerCaseRange = stringKey.rangeOfCharacter(
                        from: CharacterSet.lowercaseLetters,
                        options: [],
                        range: searchRange
                    )
                else {
                    // There are no more lower case letters. Just end here.
                    wordStart = searchRange.lowerBound
                    break
                }

                // Is the next lowercase letter more than 1 after the uppercase? If so, we encountered a group of uppercase letters that we should treat as its own word
                let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
                if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                    // The next character after capital is a lower case character and therefore not a word boundary.
                    // Continue searching for the next upper case for the boundary.
                    wordStart = upperCaseRange.lowerBound
                } else {
                    // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                    let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                    words.append(upperCaseRange.lowerBound ..< beforeLowerIndex)

                    // Next word starts at the capital before the lowercase we just found
                    wordStart = beforeLowerIndex
                }
                searchRange = lowerCaseRange.upperBound ..< searchRange.upperBound
            }
            words.append(wordStart ..< searchRange.upperBound)
            let result = words.map { range in
                stringKey[range].lowercased()
            }.joined(separator: "_")
            return result
        }
    }

    /// The output format to produce. Defaults to `[]`.
    open var outputFormatting: OutputFormatting = []

    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
    open var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    open var dataEncodingStrategy: DataEncodingStrategy = .base64

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw

    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
    open var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys

    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let dateEncodingStrategy: DateEncodingStrategy
        let dataEncodingStrategy: DataEncodingStrategy
        let nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy
        let keyEncodingStrategy: KeyEncodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(
            dateEncodingStrategy: dateEncodingStrategy,
            dataEncodingStrategy: dataEncodingStrategy,
            nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
            keyEncodingStrategy: keyEncodingStrategy,
            userInfo: userInfo
        )
    }

    // MARK: - Constructing a Any Encoder

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Encoding Values

    /// Encodes the given top-level value and returns its Any representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded Any data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<T: Encodable>(_ value: T) throws -> Any {
        let encoder = _AnyEncoder(options: options)

        guard let topLevel = try encoder.box_(value) else {
            throw EncodingError.invalidValue(
                value,
                EncodingError
                    .Context(
                        codingPath: [],
                        debugDescription: "Top-level \(T.self) did not encode any values."
                    )
            )
        }

        return try AnySerialization.map(with: topLevel)
    }
}

// MARK: - _AnyEncoder

private class _AnyEncoder: Encoder {
    // MARK: Properties

    /// The encoder's storage.
    fileprivate var storage: _AnyEncodingStorage

    /// Options set on the top-level encoder.
    fileprivate let options: AnyEncoder._Options

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    fileprivate init(options: AnyEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        storage = _AnyEncodingStorage()
        self.codingPath = codingPath
    }

    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    fileprivate var canEncodeNewValue: Bool {
        // Every time a new value gets encoded, the key it's encoded for is pushed onto the coding path (even if it's a nil key from an unkeyed container).
        // At the same time, every time a container is requested, a new value gets pushed onto the storage stack.
        // If there are more values on the storage stack than on the coding path, it means the value is requesting more than one container, which violates the precondition.
        //
        // This means that anytime something that can request a new container goes onto the stack, we MUST push a key onto the coding path.
        // Things which will not request containers do not need to have the coding path extended for them (but it doesn't matter if it is, because they will not reach here).
        return storage.count == codingPath.count
    }

    // MARK: - Encoder Methods

    public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        let topContainer: NSMutableDictionary
        if canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = storage.pushKeyedContainer()
        } else {
            guard let container = storage.containers.last as? NSMutableDictionary else {
                preconditionFailure(
                    "Attempt to push new keyed encoding container when already previously encoded at this path."
                )
            }

            topContainer = container
        }

        let container = _AnyKeyedEncodingContainer<Key>(
            referencing: self,
            codingPath: codingPath,
            wrapping: topContainer
        )
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: NSMutableArray
        if canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = storage.pushUnkeyedContainer()
        } else {
            guard let container = storage.containers.last as? NSMutableArray else {
                preconditionFailure(
                    "Attempt to push new unkeyed encoding container when already previously encoded at this path."
                )
            }

            topContainer = container
        }

        return _AnyUnkeyedEncodingContainer(
            referencing: self,
            codingPath: codingPath,
            wrapping: topContainer
        )
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

// MARK: - Encoding Storage and Containers

private struct _AnyEncodingStorage {
    // MARK: Properties

    /// The container stack.
    /// Elements may be any one of the Any types (NSNull, NSNumber, NSString, NSArray, NSDictionary).
    fileprivate private(set) var containers: [NSObject] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return containers.count
    }

    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        containers.append(array)
        return array
    }

    fileprivate mutating func push(container: NSObject) {
        containers.append(container)
    }

    fileprivate mutating func popContainer() -> NSObject {
        precondition(!containers.isEmpty, "Empty container stack.")
        return containers.popLast()!
    }
}

// MARK: - Encoding Containers

private struct _AnyKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: _AnyEncoder

    /// A reference to the container we're writing to.
    private let container: NSMutableDictionary

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(
        referencing encoder: _AnyEncoder,
        codingPath: [CodingKey],
        wrapping container: NSMutableDictionary
    ) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    // MARK: - Coding Path Operations

    private func _converted(_ key: CodingKey) -> CodingKey {
        switch encoder.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key
        case .convertToSnakeCase:
            let newKeyString = AnyEncoder.KeyEncodingStrategy._convertToSnakeCase(key.stringValue)
            return _AnyKey(stringValue: newKeyString, intValue: key.intValue)
        case let .custom(converter):
            return converter(codingPath + [key])
        }
    }

    // MARK: - KeyedEncodingContainerProtocol Methods

    public mutating func encodeNil(forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = NSNull()
    }

    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Int, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: String, forKey key: Key) throws {
        container[_converted(key).stringValue._bridgeToObjectiveC()] = encoder.box(value)
    }

    public mutating func encode(_ value: Float, forKey key: Key) throws {
        // Since the float may be invalid and throw, the coding path needs to contain this key.
        encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        #if DEPLOYMENT_RUNTIME_SWIFT
            container[_converted(key).stringValue._bridgeToObjectiveC()] = try encoder.box(value)
        #else
            container[_converted(key).stringValue] = try encoder.box(value)
        #endif
    }

    public mutating func encode(_ value: Double, forKey key: Key) throws {
        // Since the double may be invalid and throw, the coding path needs to contain this key.
        encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        #if DEPLOYMENT_RUNTIME_SWIFT
            container[_converted(key).stringValue._bridgeToObjectiveC()] = try encoder.box(value)
        #else
            container[_converted(key).stringValue] = try encoder.box(value)
        #endif
    }

    public mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        #if DEPLOYMENT_RUNTIME_SWIFT
            container[_converted(key).stringValue._bridgeToObjectiveC()] = try encoder.box(value)
        #else
            container[_converted(key).stringValue] = try encoder.box(value)
        #endif
    }

    public mutating func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        let dictionary = NSMutableDictionary()
        #if DEPLOYMENT_RUNTIME_SWIFT
            self.container[_converted(key).stringValue._bridgeToObjectiveC()] = dictionary
        #else
            self.container[_converted(key).stringValue] = dictionary
        #endif

        codingPath.append(key)
        defer { self.codingPath.removeLast() }

        let container = _AnyKeyedEncodingContainer<NestedKey>(
            referencing: encoder,
            codingPath: codingPath,
            wrapping: dictionary
        )
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let array = NSMutableArray()
        #if DEPLOYMENT_RUNTIME_SWIFT
            container[_converted(key).stringValue._bridgeToObjectiveC()] = array
        #else
            container[_converted(key).stringValue] = array
        #endif

        codingPath.append(key)
        defer { self.codingPath.removeLast() }
        return _AnyUnkeyedEncodingContainer(
            referencing: encoder,
            codingPath: codingPath,
            wrapping: array
        )
    }

    public mutating func superEncoder() -> Encoder {
        return _AnyReferencingEncoder(referencing: encoder, at: _AnyKey.super, wrapping: container)
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _AnyReferencingEncoder(referencing: encoder, at: key, wrapping: container)
    }
}

private struct _AnyUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: _AnyEncoder

    /// A reference to the container we're writing to.
    private let container: NSMutableArray

    /// The path of coding keys taken to get to this point in encoding.
    public private(set) var codingPath: [CodingKey]

    /// The number of elements encoded into the container.
    public var count: Int {
        return container.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(
        referencing encoder: _AnyEncoder,
        codingPath: [CodingKey],
        wrapping container: NSMutableArray
    ) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }

    // MARK: - UnkeyedEncodingContainer Methods

    public mutating func encodeNil() throws { container.add(NSNull()) }
    public mutating func encode(_ value: Bool) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: Int) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: Int8) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: Int16) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: Int32) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: Int64) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: UInt) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: UInt8) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: UInt16) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: UInt32) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: UInt64) throws { container.add(encoder.box(value)) }
    public mutating func encode(_ value: String) throws { container.add(encoder.box(value)) }

    public mutating func encode(_ value: Float) throws {
        // Since the float may be invalid and throw, the coding path needs to contain this key.
        encoder.codingPath.append(_AnyKey(index: count))
        defer { self.encoder.codingPath.removeLast() }
        container.add(try encoder.box(value))
    }

    public mutating func encode(_ value: Double) throws {
        // Since the double may be invalid and throw, the coding path needs to contain this key.
        encoder.codingPath.append(_AnyKey(index: count))
        defer { self.encoder.codingPath.removeLast() }
        container.add(try encoder.box(value))
    }

    public mutating func encode<T: Encodable>(_ value: T) throws {
        encoder.codingPath.append(_AnyKey(index: count))
        defer { self.encoder.codingPath.removeLast() }
        container.add(try encoder.box(value))
    }

    public mutating func nestedContainer<NestedKey>(
        keyedBy _: NestedKey
            .Type
    ) -> KeyedEncodingContainer<NestedKey> {
        codingPath.append(_AnyKey(index: count))
        defer { self.codingPath.removeLast() }

        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)

        let container = _AnyKeyedEncodingContainer<NestedKey>(
            referencing: encoder,
            codingPath: codingPath,
            wrapping: dictionary
        )
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        codingPath.append(_AnyKey(index: count))
        defer { self.codingPath.removeLast() }

        let array = NSMutableArray()
        container.add(array)
        return _AnyUnkeyedEncodingContainer(
            referencing: encoder,
            codingPath: codingPath,
            wrapping: array
        )
    }

    public mutating func superEncoder() -> Encoder {
        return _AnyReferencingEncoder(
            referencing: encoder,
            at: container.count,
            wrapping: container
        )
    }
}

extension _AnyEncoder: SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    fileprivate func assertCanEncodeNewValue() {
        precondition(
            canEncodeNewValue,
            "Attempt to encode value through single value container when previously value already encoded."
        )
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        storage.push(container: NSNull())
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        storage.push(container: box(value))
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        try storage.push(container: box(value))
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        try storage.push(container: box(value))
    }

    public func encode<T: Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        try storage.push(container: box(value))
    }
}

// MARK: - Concrete Value Representations

private extension _AnyEncoder {
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    func box(_ value: Bool) -> NSObject { return NSNumber(value: value) }
    func box(_ value: Int) -> NSObject { return NSNumber(value: value) }
    func box(_ value: Int8) -> NSObject { return NSNumber(value: value) }
    func box(_ value: Int16) -> NSObject { return NSNumber(value: value) }
    func box(_ value: Int32) -> NSObject { return NSNumber(value: value) }
    func box(_ value: Int64) -> NSObject { return NSNumber(value: value) }
    func box(_ value: UInt) -> NSObject { return NSNumber(value: value) }
    func box(_ value: UInt8) -> NSObject { return NSNumber(value: value) }
    func box(_ value: UInt16) -> NSObject { return NSNumber(value: value) }
    func box(_ value: UInt32) -> NSObject { return NSNumber(value: value) }
    func box(_ value: UInt64) -> NSObject { return NSNumber(value: value) }
    func box(_ value: String) -> NSObject { return NSString(string: value) }

    func box(_ float: Float) throws -> NSObject {
        guard !float.isInfinite, !float.isNaN else {
            guard
                case let .convertToString(
                    positiveInfinity: posInfString,
                    negativeInfinity: negInfString,
                    nan: nanString
                ) = options.nonConformingFloatEncodingStrategy
            else {
                throw EncodingError._invalidFloatingPointValue(float, at: codingPath)
            }

            if float == Float.infinity {
                return NSString(string: posInfString)
            } else if float == -Float.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }

        return NSNumber(value: float)
    }

    func box(_ double: Double) throws -> NSObject {
        guard !double.isInfinite, !double.isNaN else {
            guard
                case let .convertToString(
                    positiveInfinity: posInfString,
                    negativeInfinity: negInfString,
                    nan: nanString
                ) = options.nonConformingFloatEncodingStrategy
            else {
                throw EncodingError._invalidFloatingPointValue(double, at: codingPath)
            }

            if double == Double.infinity {
                return NSString(string: posInfString)
            } else if double == -Double.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }

        return NSNumber(value: double)
    }

    func box(_ date: Date) throws -> NSObject {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            // Must be called with a surrounding with(pushedKey:) call.
            // Dates encode as single-value objects; this can't both throw and push a container, so no need to catch the error.
            try date.encode(to: self)
            return storage.popContainer()

        case .secondsSince1970:
            return NSNumber(value: date.timeIntervalSince1970)

        case .millisecondsSince1970:
            return NSNumber(value: 1000.0 * date.timeIntervalSince1970)

        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                return NSString(string: _iso8601Formatter.string(from: date))
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }

        case let .formatted(formatter):
            return NSString(string: formatter.string(from: date))

        case let .custom(closure):
            let depth = storage.count
            do {
                try closure(date, self)
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                if storage.count > depth {
                    _ = storage.popContainer()
                }
                throw error
            }

            guard storage.count > depth else {
                // The closure didn't encode anything. Return the default keyed container.
                return NSDictionary()
            }

            // We can pop because the closure encoded something.
            return storage.popContainer()
        }
    }

    func box(_ data: Data) throws -> NSObject {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            // Must be called with a surrounding with(pushedKey:) call.
            let depth = storage.count
            do {
                try data.encode(to: self)
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                // This shouldn't be possible for Data (which encodes as an array of bytes), but it can't hurt to catch a failure.
                if storage.count > depth {
                    _ = storage.popContainer()
                }
                throw error
            }
            return storage.popContainer()

        case .base64:
            return NSString(string: data.base64EncodedString())

        case let .custom(closure):
            let depth = storage.count
            do {
                try closure(data, self)
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                if storage.count > depth {
                    _ = storage.popContainer()
                }
                throw error
            }

            guard storage.count > depth else {
                // The closure didn't encode anything. Return the default keyed container.
                return NSDictionary()
            }
            // We can pop because the closure encoded something.
            return storage.popContainer()
        }
    }

    func box(_ dict: [String: Encodable]) throws -> NSObject? {
        let depth = storage.count
        let result = storage.pushKeyedContainer()
        do {
            for (key, value) in dict {
                codingPath.append(_AnyKey(stringValue: key, intValue: nil))
                defer { self.codingPath.removeLast() }
                result[key] = try box(value)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if storage.count > depth {
                let _ = storage.popContainer()
            }

            throw error
        }

        // The top container should be a new container.
        guard storage.count > depth else {
            return nil
        }

        return storage.popContainer()
    }

    func box(_ value: Encodable) throws -> NSObject {
        return try box_(value) ?? NSDictionary()
    }

    // This method is called "box_" instead of "box" to disambiguate it from the overloads. Because the return type here is different from all of the "box" overloads (and is more general), any "box" calls in here would call back into "box" recursively instead of calling the appropriate overload, which is not what we want.
    func box_(_ value: Encodable) throws -> NSObject? {
        let type = Swift.type(of: value)
        #if DEPLOYMENT_RUNTIME_SWIFT
            if type == Date.self {
                // Respect Date encoding strategy
                return try box(value as! Date)
            } else if type == Data.self {
                // Respect Data encoding strategy
                return try box(value as! Data)
            } else if type == URL.self {
                // Encode URLs as single strings.
                return box((value as! URL).absoluteString)
            } else if type == Decimal.self {
                // AnySerialization can consume NSDecimalNumber values.
                return NSDecimalNumber(decimal: value as! Decimal)
            } else if value is _AnyStringDictionaryEncodableMarker {
                return try box((value as Any) as! [String: Encodable])
            }

        #else
            if type == Date.self || type == NSDate.self {
                // Respect Date encoding strategy
                return try box(value as! Date)
            } else if type == Data.self || type == NSData.self {
                // Respect Data encoding strategy
                return try box(value as! Data)
            } else if type == URL.self || type == NSURL.self {
                // Encode URLs as single strings.
                return box((value as! URL).absoluteString)
            } else if type == Decimal.self {
                // AnySerialization can consume NSDecimalNumber values.
                return NSDecimalNumber(decimal: value as! Decimal)
            } else if value is _AnyStringDictionaryEncodableMarker {
                return try box((value as Any) as! [String: Encodable])
            }
        #endif

        // The value should request a container from the _AnyEncoder.
        let depth = storage.count
        do {
            try value.encode(to: self)
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if storage.count > depth {
                let _ = storage.popContainer()
            }
            throw error
        }

        // The top container should be a new container.
        guard storage.count > depth else {
            return nil
        }

        return storage.popContainer()
    }
}

// MARK: - _AnyReferencingEncoder

/// _AnyReferencingEncoder is a special subclass of _AnyEncoder which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
private class _AnyReferencingEncoder: _AnyEncoder {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(NSMutableArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(NSMutableDictionary, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    fileprivate let encoder: _AnyEncoder

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    fileprivate init(
        referencing encoder: _AnyEncoder,
        at index: Int,
        wrapping array: NSMutableArray
    ) {
        self.encoder = encoder
        reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        codingPath.append(_AnyKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(
        referencing encoder: _AnyEncoder,
        at key: CodingKey,
        wrapping dictionary: NSMutableDictionary
    ) {
        self.encoder = encoder
        reference = .dictionary(dictionary, key.stringValue)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        codingPath.append(key)
    }

    // MARK: - Coding Path Operations

    override fileprivate var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return storage.count == codingPath.count - encoder.codingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case let .array(array, index):
            array.insert(value, at: index)

        case let .dictionary(dictionary, key):
            dictionary[NSString(string: key)] = value
        }
    }
}

//===----------------------------------------------------------------------===//
// Any Decoder
//===----------------------------------------------------------------------===//

/// `AnyDecoder` facilitates the decoding of Any into semantic `Decodable` types.
open class AnyDecoder {
    // MARK: Options

    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate

        /// Decode the `Date` as a UNIX timestamp from a Any number.
        case secondsSince1970

        /// Decode the `Date` as UNIX millisecond timestamp from a Any number.
        case millisecondsSince1970

        /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Decode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Decode the `Date` as a custom value decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Date)
    }

    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy {
        /// Defer to `Data` for decoding.
        case deferredToData

        /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
        case base64

        /// Decode the `Data` as a custom value decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Data)
    }

    /// The strategy to use for non-Any-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatDecodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Decode the values from the given representation strings.
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before decoding.
    public enum KeyDecodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys

        /// Convert from "snake_case_keys" to "camelCaseKeys" before attempting to match a key with the one specified by each type.
        ///
        /// The conversion to upper case uses `Locale.system`, also known as the ICU "root" locale. This means the result is consistent regardless of the current user's locale and language preferences.
        ///
        /// Converting from snake case to camel case:
        /// 1. Capitalizes the word starting after each `_`
        /// 2. Removes all `_`
        /// 3. Preserves starting and ending `_` (as these are often used to indicate private variables or other metadata).
        /// For example, `one_two_three` becomes `oneTwoThree`. `_one_two_three_` becomes `_oneTwoThree_`.
        ///
        /// - Note: Using a key decoding strategy has a nominal performance cost, as each string key has to be inspected for the `_` character.
        case convertFromSnakeCase

        /// Provide a custom conversion from the key in the encoded Any to the keys specified by the decoded types.
        /// The full path to the current decoding position is provided for context (in case you need to locate this key within the payload). The returned key is used in place of the last component in the coding path before decoding.
        /// If the result of the conversion is a duplicate key, then only one value will be present in the container for the type to decode from.
        case custom((_ codingPath: [CodingKey]) -> CodingKey)

        fileprivate static func _convertFromSnakeCase(_ stringKey: String) -> String {
            guard !stringKey.isEmpty else { return stringKey }

            // Find the first non-underscore character
            guard let firstNonUnderscore = stringKey.firstIndex(where: { $0 != "_" }) else {
                // Reached the end without finding an _
                return stringKey
            }

            // Find the last non-underscore character
            var lastNonUnderscore = stringKey.index(before: stringKey.endIndex)
            while lastNonUnderscore > firstNonUnderscore, stringKey[lastNonUnderscore] == "_" {
                stringKey.formIndex(before: &lastNonUnderscore)
            }

            let keyRange = firstNonUnderscore ... lastNonUnderscore
            let leadingUnderscoreRange = stringKey.startIndex ..< firstNonUnderscore
            let trailingUnderscoreRange = stringKey.index(after: lastNonUnderscore) ..< stringKey
                .endIndex

            let components = stringKey[keyRange].split(separator: "_")
            let joinedString: String
            if components.count == 1 {
                // No underscores in key, leave the word as is - maybe already camel cased
                joinedString = String(stringKey[keyRange])
            } else {
                joinedString = (
                    [components[0].lowercased()] + components[1...]
                        .map { $0.capitalized }
                ).joined()
            }

            // Do a cheap isEmpty check before creating and appending potentially empty strings
            let result: String
            if leadingUnderscoreRange.isEmpty, trailingUnderscoreRange.isEmpty {
                result = joinedString
            } else if !leadingUnderscoreRange.isEmpty, !trailingUnderscoreRange.isEmpty {
                // Both leading and trailing underscores
                result = String(stringKey[leadingUnderscoreRange]) + joinedString +
                    String(stringKey[trailingUnderscoreRange])
            } else if !leadingUnderscoreRange.isEmpty {
                // Just leading
                result = String(stringKey[leadingUnderscoreRange]) + joinedString
            } else {
                // Just trailing
                result = joinedString + String(stringKey[trailingUnderscoreRange])
            }
            return result
        }
    }

    /// The strategy to use in decoding dates. Defaults to `.deferredToDate`.
    open var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    open var dataDecodingStrategy: DataDecodingStrategy = .base64

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw

    /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
    open var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    fileprivate struct _Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let dataDecodingStrategy: DataDecodingStrategy
        let nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy
        let keyDecodingStrategy: KeyDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level decoder.
    fileprivate var options: _Options {
        return _Options(
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy,
            userInfo: userInfo
        )
    }

    // MARK: - Constructing a Any Decoder

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Decoding Values

    /// Decodes a top-level value of the given type from the given Any representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter map: The map to decode from.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid Any.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T: Decodable>(_ type: T.Type, from map: Any) throws -> T {
        let topLevel = try AnySerialization.object(with: map)
        let decoder = _AnyDecoder(referencing: topLevel, options: options)

        guard let value = try decoder.unbox(topLevel, as: type) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "The given data did not contain a top-level value."
                )
            )
        }

        return value
    }
}

// MARK: - _AnyDecoder

private class _AnyDecoder: Decoder {
    // MARK: Properties

    /// The decoder's storage.
    fileprivate var storage: _AnyDecodingStorage

    /// Options set on the top-level decoder.
    fileprivate let options: AnyDecoder._Options

    /// The path to the current point in encoding.
    public fileprivate(set) var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    fileprivate init(
        referencing container: Any,
        at codingPath: [CodingKey] = [],
        options: AnyDecoder._Options
    ) {
        storage = _AnyDecodingStorage()
        storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }

    // MARK: - Decoder Methods

    public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard !(storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<Key>.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get keyed decoding container -- found null value instead."
                )
            )
        }

        guard let topContainer = storage.topContainer as? [String: Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [String: Any].self,
                reality: storage.topContainer
            )
        }

        let container = _AnyKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !(storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead."
                )
            )
        }

        guard let topContainer = storage.topContainer as? [Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [Any].self,
                reality: storage.topContainer
            )
        }

        return _AnyUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

// MARK: - Decoding Storage

private struct _AnyDecodingStorage {
    // MARK: Properties

    /// The container stack.
    /// Elements may be any one of the Any types (NSNull, NSNumber, String, Array, [String : Any]).
    fileprivate private(set) var containers: [Any] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return containers.count
    }

    fileprivate var topContainer: Any {
        precondition(!containers.isEmpty, "Empty container stack.")
        return containers.last!
    }

    fileprivate mutating func push(container: Any) {
        containers.append(container)
    }

    fileprivate mutating func popContainer() {
        precondition(!containers.isEmpty, "Empty container stack.")
        containers.removeLast()
    }
}

// MARK: Decoding Containers

private struct _AnyKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: _AnyDecoder

    /// A reference to the container we're reading from.
    private let container: [String: Any]

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _AnyDecoder, wrapping container: [String: Any]) {
        self.decoder = decoder
        switch decoder.options.keyDecodingStrategy {
        case .useDefaultKeys:
            self.container = container
        case .convertFromSnakeCase:
            // Convert the snake case keys in the container to camel case.
            // If we hit a duplicate key after conversion, then we'll use the first one we saw. Effectively an undefined behavior with Any dictionaries.
            self.container = Dictionary(container.map {
                key, value in (AnyDecoder.KeyDecodingStrategy._convertFromSnakeCase(key), value)
            }, uniquingKeysWith: { first, _ in first })
        case let .custom(converter):
            self.container = Dictionary(container.map {
                key, value in (
                    converter(decoder.codingPath + [_AnyKey(stringValue: key, intValue: nil)])
                        .stringValue,
                    value
                )
            }, uniquingKeysWith: { first, _ in first })
        }
        codingPath = decoder.codingPath
    }

    // MARK: - KeyedDecodingContainerProtocol Methods

    public var allKeys: [Key] {
        return container.keys.compactMap { Key(stringValue: $0) }
    }

    public func contains(_ key: Key) -> Bool {
        return container[key.stringValue] != nil
    }

    private func _errorDescription(of key: CodingKey) -> String {
        switch decoder.options.keyDecodingStrategy {
        case .convertFromSnakeCase:
            // In this case we can attempt to recover the original value by reversing the transform
            let original = key.stringValue
            let converted = AnyEncoder.KeyEncodingStrategy._convertToSnakeCase(original)
            if converted == original {
                return "\(key) (\"\(original)\")"
            } else {
                return "\(key) (\"\(original)\"), converted to \(converted)"
            }
        default:
            // Otherwise, just report the converted string
            return "\(key) (\"\(key.stringValue)\")"
        }
    }

    public func decodeNil(forKey key: Key) throws -> Bool {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        return entry is NSNull
    }

    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Bool.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Int.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Int8.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Int16.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Int32.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Int64.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: UInt.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: UInt8.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: UInt16.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: UInt32.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: UInt64.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Float.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: Double.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: String.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No value associated with key \(_errorDescription(of: key))."
                    )
            )
        }

        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try decoder.unbox(entry, as: type) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected \(type) value but found null instead."
                    )
            )
        }

        return value
    }

    public func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key
    ) throws
        -> KeyedDecodingContainer<NestedKey>
    {
        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get \(KeyedDecodingContainer<NestedKey>.self) -- no value found for key \(_errorDescription(of: key))"
                )
            )
        }

        guard let dictionary = value as? [String: Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [String: Any].self,
                reality: value
            )
        }

        let container = _AnyKeyedDecodingContainer<NestedKey>(
            referencing: decoder,
            wrapping: dictionary
        )
        return KeyedDecodingContainer(container)
    }

    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get UnkeyedDecodingContainer -- no value found for key \(_errorDescription(of: key))"
                )
            )
        }

        guard let array = value as? [Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [Any].self,
                reality: value
            )
        }

        return _AnyUnkeyedDecodingContainer(referencing: decoder, wrapping: array)
    }

    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        let value: Any = container[key.stringValue] ?? NSNull()
        return _AnyDecoder(referencing: value, at: decoder.codingPath, options: decoder.options)
    }

    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _AnyKey.super)
    }

    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

private struct _AnyUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: _AnyDecoder

    /// A reference to the container we're reading from.
    private let container: [Any]

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    /// The index of the element we're about to decode.
    public private(set) var currentIndex: Int

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _AnyDecoder, wrapping container: [Any]) {
        self.decoder = decoder
        self.container = container
        codingPath = decoder.codingPath
        currentIndex = 0
    }

    // MARK: - UnkeyedDecodingContainer Methods

    public var count: Int? {
        return container.count
    }

    public var isAtEnd: Bool {
        return currentIndex >= count!
    }

    public mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        if container[currentIndex] is NSNull {
            currentIndex += 1
            return true
        } else {
            return false
        }
    }

    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Bool.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int.Type) throws -> Int {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Int.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Int8.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Int16.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Int32.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Int64.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: UInt.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: UInt8.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: UInt16.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: UInt32.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: UInt64.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Float.Type) throws -> Float {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Float.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Double.Type) throws -> Double {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: Double.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: String.Type) throws -> String {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: String.self) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
            )
        }

        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try decoder.unbox(container[currentIndex], as: type) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: decoder.codingPath + [_AnyKey(index: currentIndex)],
                        debugDescription: "Expected \(type) but found null instead."
                    )
            )
        }

        currentIndex += 1
        return decoded
    }

    public mutating func nestedContainer<NestedKey>(
        keyedBy _: NestedKey
            .Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<NestedKey>.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."
                )
            )
        }

        let value = self.container[currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<NestedKey>.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get keyed decoding container -- found null value instead."
                )
            )
        }

        guard let dictionary = value as? [String: Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [String: Any].self,
                reality: value
            )
        }

        currentIndex += 1
        let container = _AnyKeyedDecodingContainer<NestedKey>(
            referencing: decoder,
            wrapping: dictionary
        )
        return KeyedDecodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."
                )
            )
        }

        let value = container[currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get keyed decoding container -- found null value instead."
                )
            )
        }

        guard let array = value as? [Any] else {
            throw DecodingError._typeMismatch(
                at: codingPath,
                expectation: [Any].self,
                reality: value
            )
        }

        currentIndex += 1
        return _AnyUnkeyedDecodingContainer(referencing: decoder, wrapping: array)
    }

    public mutating func superDecoder() throws -> Decoder {
        decoder.codingPath.append(_AnyKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Decoder.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."
                )
            )
        }

        let value = container[currentIndex]
        currentIndex += 1
        return _AnyDecoder(referencing: value, at: decoder.codingPath, options: decoder.options)
    }
}

extension _AnyDecoder: SingleValueDecodingContainer {
    // MARK: SingleValueDecodingContainer Methods

    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !decodeNil() else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError
                    .Context(
                        codingPath: codingPath,
                        debugDescription: "Expected \(type) but found null value instead."
                    )
            )
        }
    }

    public func decodeNil() -> Bool {
        return storage.topContainer is NSNull
    }

    public func decode(_: Bool.Type) throws -> Bool {
        try expectNonNull(Bool.self)
        return try unbox(storage.topContainer, as: Bool.self)!
    }

    public func decode(_: Int.Type) throws -> Int {
        try expectNonNull(Int.self)
        return try unbox(storage.topContainer, as: Int.self)!
    }

    public func decode(_: Int8.Type) throws -> Int8 {
        try expectNonNull(Int8.self)
        return try unbox(storage.topContainer, as: Int8.self)!
    }

    public func decode(_: Int16.Type) throws -> Int16 {
        try expectNonNull(Int16.self)
        return try unbox(storage.topContainer, as: Int16.self)!
    }

    public func decode(_: Int32.Type) throws -> Int32 {
        try expectNonNull(Int32.self)
        return try unbox(storage.topContainer, as: Int32.self)!
    }

    public func decode(_: Int64.Type) throws -> Int64 {
        try expectNonNull(Int64.self)
        return try unbox(storage.topContainer, as: Int64.self)!
    }

    public func decode(_: UInt.Type) throws -> UInt {
        try expectNonNull(UInt.self)
        return try unbox(storage.topContainer, as: UInt.self)!
    }

    public func decode(_: UInt8.Type) throws -> UInt8 {
        try expectNonNull(UInt8.self)
        return try unbox(storage.topContainer, as: UInt8.self)!
    }

    public func decode(_: UInt16.Type) throws -> UInt16 {
        try expectNonNull(UInt16.self)
        return try unbox(storage.topContainer, as: UInt16.self)!
    }

    public func decode(_: UInt32.Type) throws -> UInt32 {
        try expectNonNull(UInt32.self)
        return try unbox(storage.topContainer, as: UInt32.self)!
    }

    public func decode(_: UInt64.Type) throws -> UInt64 {
        try expectNonNull(UInt64.self)
        return try unbox(storage.topContainer, as: UInt64.self)!
    }

    public func decode(_: Float.Type) throws -> Float {
        try expectNonNull(Float.self)
        return try unbox(storage.topContainer, as: Float.self)!
    }

    public func decode(_: Double.Type) throws -> Double {
        try expectNonNull(Double.self)
        return try unbox(storage.topContainer, as: Double.self)!
    }

    public func decode(_: String.Type) throws -> String {
        try expectNonNull(String.self)
        return try unbox(storage.topContainer, as: String.self)!
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(type)
        return try unbox(storage.topContainer, as: type)!
    }
}

// MARK: - Concrete Value Representations

private extension _AnyDecoder {
    /// Returns the given value unboxed from a container.
    func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        guard !(value is NSNull) else { return nil }

        #if DEPLOYMENT_RUNTIME_SWIFT || os(Linux)
            // Bridging differences require us to split implementations here
            guard let number = __SwiftValue.store(value) as? NSNumber else {
                throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
            }

            // TODO: Add a flag to coerce non-boolean numbers into Bools?
            guard CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
            }

            return number.boolValue
        #else
            if let number = value as? NSNumber {
                // TODO: Add a flag to coerce non-boolean numbers into Bools?
                if number === kCFBooleanTrue as NSNumber {
                    return true
                } else if number === kCFBooleanFalse as NSNumber {
                    return false
                }

                /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
                 } else if let bool = value as? Bool {
                 return bool
                 */
            }

            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        #endif
    }

    func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let int = number.intValue
        guard NSNumber(value: int) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return int
    }

    func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let int8 = number.int8Value
        guard NSNumber(value: int8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return int8
    }

    func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let int16 = number.int16Value
        guard NSNumber(value: int16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return int16
    }

    func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return int32
    }

    func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let int64 = number.int64Value
        guard NSNumber(value: int64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return int64
    }

    func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let uint = number.uintValue
        guard NSNumber(value: uint) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return uint
    }

    func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let uint8 = number.uint8Value
        guard NSNumber(value: uint8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return uint8
    }

    func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let uint16 = number.uint16Value
        guard NSNumber(value: uint16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return uint16
    }

    func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let uint32 = number.uint32Value
        guard NSNumber(value: uint32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return uint32
    }

    func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
        guard !(value is NSNull) else { return nil }

        guard
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        let uint64 = number.uint64Value
        guard NSNumber(value: uint64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Parsed Any number <\(number)> does not fit in \(type)."
            ))
        }

        return uint64
    }

    func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
        guard !(value is NSNull) else { return nil }

        if
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        {
            // We are willing to return a Float by losing precision:
            // * If the original value was integral,
            //   * and the integral value was > Float.greatestFiniteMagnitude, we will fail
            //   * and the integral value was <= Float.greatestFiniteMagnitude, we are willing to lose precision past 2^24
            // * If it was a Float, you will get back the precise value
            // * If it was a Double or Decimal, you will get back the nearest approximation if it will fit
            let double = number.doubleValue
            guard abs(double) <= Double(Float.greatestFiniteMagnitude) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Parsed Any number \(number) does not fit in \(type)."
                ))
            }

            return Float(double)

            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
                 if abs(double) <= Double(Float.max) {
                     return Float(double)
                 }
                 overflow = true
             } else if let int = value as? Int {
                 if let float = Float(exactly: int) {
                     return float
                 }

                  overflow = true
                  */

        } else if
            let string = value as? String,
            case let .convertFromString(posInfString, negInfString, nanString) = options
                .nonConformingFloatDecodingStrategy
        {
            if string == posInfString {
                return Float.infinity
            } else if string == negInfString {
                return -Float.infinity
            } else if string == nanString {
                return Float.nan
            }
        }

        throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
    }

    func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
        guard !(value is NSNull) else { return nil }

        if
            let number = __SwiftValue.store(value) as? NSNumber, number !== kCFBooleanTrue,
            number !== kCFBooleanFalse
        {
            // We are always willing to return the number as a Double:
            // * If the original value was integral, it is guaranteed to fit in a Double; we are willing to lose precision past 2^53 if you encoded a UInt64 but requested a Double
            // * If it was a Float or Double, you will get back the precise value
            // * If it was Decimal, you will get back the nearest approximation
            return number.doubleValue

            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
                 return double
             } else if let int = value as? Int {
                 if let double = Double(exactly: int) {
                     return double
                  }

              overflow = true
              */

        } else if
            let string = value as? String,
            case let .convertFromString(posInfString, negInfString, nanString) = options
                .nonConformingFloatDecodingStrategy
        {
            if string == posInfString {
                return Double.infinity
            } else if string == negInfString {
                return -Double.infinity
            } else if string == nanString {
                return Double.nan
            }
        }

        throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
    }

    func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }

        guard let string = value as? String else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }

        return string
    }

    func unbox(_ value: Any, as _: Date.Type) throws -> Date? {
        guard !(value is NSNull) else { return nil }

        switch options.dateDecodingStrategy {
        case .deferredToDate:
            storage.push(container: value)
            defer { self.storage.popContainer() }
            return try Date(from: self)

        case .secondsSince1970:
            let double = try unbox(value, as: Double.self)!
            return Date(timeIntervalSince1970: double)

        case .millisecondsSince1970:
            let double = try unbox(value, as: Double.self)!
            return Date(timeIntervalSince1970: double / 1000.0)

        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                let string = try self.unbox(value, as: String.self)!
                guard let date = _iso8601Formatter.date(from: string) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Expected date string to be ISO8601-formatted."
                    ))
                }

                return date
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }

        case let .formatted(formatter):
            let string = try unbox(value, as: String.self)!
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Date string does not match format expected by formatter."
                ))
            }

            return date

        case let .custom(closure):
            storage.push(container: value)
            defer { self.storage.popContainer() }
            return try closure(self)
        }
    }

    func unbox(_ value: Any, as type: Data.Type) throws -> Data? {
        guard !(value is NSNull) else { return nil }

        switch options.dataDecodingStrategy {
        case .deferredToData:
            storage.push(container: value)
            defer { self.storage.popContainer() }
            return try Data(from: self)

        case .base64:
            guard let string = value as? String else {
                throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
            }

            guard let data = Data(base64Encoded: string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Encountered Data is not valid Base64."
                ))
            }

            return data

        case let .custom(closure):
            storage.push(container: value)
            defer { self.storage.popContainer() }
            return try closure(self)
        }
    }

    func unbox(_ value: Any, as _: Decimal.Type) throws -> Decimal? {
        guard !(value is NSNull) else { return nil }

        // Attempt to bridge from NSDecimalNumber.
        if let decimal = value as? Decimal {
            return decimal
        } else {
            let doubleValue = try unbox(value, as: Double.self)!
            return Decimal(doubleValue)
        }
    }

    func unbox<T>(_ value: Any, as type: _AnyStringDictionaryDecodableMarker.Type) throws -> T? {
        guard !(value is NSNull) else { return nil }

        var result = [String: Any]()
        guard let dict = value as? NSDictionary else {
            throw DecodingError._typeMismatch(at: codingPath, expectation: type, reality: value)
        }
        let elementType = type.elementType
        for (key, value) in dict {
            let key = key as! String
            codingPath.append(_AnyKey(stringValue: key, intValue: nil))
            defer { self.codingPath.removeLast() }

            result[key] = try unbox_(value, as: elementType)
        }

        return result as? T
    }

    func unbox<T: Decodable>(_ value: Any, as type: T.Type) throws -> T? {
        return try unbox_(value, as: type) as? T
    }

    func unbox_(_ value: Any, as type: Decodable.Type) throws -> Any? {
        #if DEPLOYMENT_RUNTIME_SWIFT
            // Bridging differences require us to split implementations here
            if type == Date.self {
                guard let date = try unbox(value, as: Date.self) else { return nil }
                return date
            } else if type == Data.self {
                guard let data = try unbox(value, as: Data.self) else { return nil }
                return data
            } else if type == URL.self {
                guard let urlString = try unbox(value, as: String.self) else {
                    return nil
                }

                guard let url = URL(string: urlString) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Invalid URL string."
                    ))
                }
                return url
            } else if type == Decimal.self {
                guard let decimal = try unbox(value, as: Decimal.self) else { return nil }
                return decimal
            } else if let stringKeyedDictType = type as? _AnyStringDictionaryDecodableMarker.Type {
                return try unbox(value, as: stringKeyedDictType)
            } else {
                storage.push(container: value)
                defer { self.storage.popContainer() }
                return try type.init(from: self)
            }
        #else
            if type == Date.self || type == NSDate.self {
                return try unbox(value, as: Date.self)
            } else if type == Data.self || type == NSData.self {
                return try unbox(value, as: Data.self)
            } else if type == URL.self || type == NSURL.self {
                guard let urlString = try unbox(value, as: String.self) else {
                    return nil
                }

                guard let url = URL(string: urlString) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Invalid URL string."
                    ))
                }

                return url
            } else if type == Decimal.self || type == NSDecimalNumber.self {
                return try unbox(value, as: Decimal.self)
            } else if let stringKeyedDictType = type as? _AnyStringDictionaryDecodableMarker.Type {
                return try unbox(value, as: stringKeyedDictType)
            } else {
                storage.push(container: value)
                defer { self.storage.popContainer() }
                return try type.init(from: self)
            }
        #endif
    }
}

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

private struct _AnyKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    public init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    fileprivate init(index: Int) {
        stringValue = "Index \(index)"
        intValue = index
    }

    fileprivate static let `super` = _AnyKey(stringValue: "super")!
}

//===----------------------------------------------------------------------===//
// Shared ISO8601 Date Formatter
//===----------------------------------------------------------------------===//

// NOTE: This value is implicitly lazy and _must_ be lazy. We're compiled against the latest SDK (w/ ISO8601DateFormatter), but linked against whichever Foundation the user has. ISO8601DateFormatter might not exist, so we better not hit this code path on an older OS.
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private var _iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

private extension EncodingError {
    /// Returns a `.invalidValue` error describing the given invalid floating-point value.
    ///
    ///
    /// - parameter value: The value that was invalid to encode.
    /// - parameter path: The path of `CodingKey`s taken to encode this value.
    /// - returns: An `EncodingError` with the appropriate path and debug description.
    static func _invalidFloatingPointValue<T: FloatingPoint>(
        _ value: T,
        at codingPath: [CodingKey]
    ) -> EncodingError {
        let valueDescription: String
        if value == T.infinity {
            valueDescription = "\(T.self).infinity"
        } else if value == -T.infinity {
            valueDescription = "-\(T.self).infinity"
        } else {
            valueDescription = "\(T.self).nan"
        }

        let debugDescription =
            "Unable to encode \(valueDescription) directly in Any. Use AnyEncoder.NonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded."
        return .invalidValue(
            value,
            EncodingError.Context(codingPath: codingPath, debugDescription: debugDescription)
        )
    }
}

private enum __SwiftValue {
    fileprivate static func store(_ any: Any) -> Any {
        return any
    }
}
