import Foundation
import OrderedCollections

public struct MapSerialization {
    static func map(with object: NSObject) throws -> Map {
        switch object {
        case is NSNull:
            return .null
        case let number as NSNumber:
            return .number(Number(number))
        case let string as NSString:
            return .string(string as String)
        case let array as NSArray:
            let array: [Map] = try array.map { value in
                guard let value = value as? NSObject else {
                    throw EncodingError.invalidValue(
                        array,
                        EncodingError.Context(
                            codingPath: [],
                            debugDescription: "Array value was not an object: \(value) in \(array)"
                        )
                    )
                }
                return try self.map(with: value)
            }
            return .array(array)
        case let dictionary as NSDictionary:
            // Extract from an unordered dictionary, using NSDictionary extraction order
            let orderedDictionary: OrderedDictionary<String, Map> = try dictionary.reduce(into: [:]) { (dictionary, pair) in
                guard let key = pair.key as? String else {
                    throw EncodingError.invalidValue(
                        dictionary,
                        EncodingError.Context(
                            codingPath: [],
                            debugDescription: "Dictionary key was not string: \(pair.key) in \(dictionary)"
                        )
                    )
                }
                guard let value = pair.value as? NSObject else{
                    throw EncodingError.invalidValue(
                        dictionary,
                        EncodingError.Context(
                            codingPath: [],
                            debugDescription: "Dictionary value was not an object: \(key) in \(dictionary)"
                        )
                    )
                }
                dictionary[key] = try self.map(with: value)
            }
            return .dictionary(orderedDictionary)
        default:
            throw EncodingError.invalidValue(
                object,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Unable to encode the given top-level value to Map."
                )
            )
        }
    }
    
    static func object(with map: Map) throws -> NSObject {
        switch map {
        case .undefined:
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "undefined values should have been excluded from serialization"
                )
            )
        case .null:
            return NSNull()
        case let .bool(value):
            return value as NSObject
        case var .number(number):
            return number.number
        case let .string(string):
            return string as NSString
        case let .array(array):
            return try array.map({ try object(with: $0) }) as NSArray
        case let .dictionary(dictionary):
            // Coerce to an unordered dictionary
            var unorderedDictionary: [String: NSObject] = [:]
            for (key, value) in dictionary {
                if !value.isUndefined {
                    try unorderedDictionary[key] = object(with: value)
                }
            }
            return unorderedDictionary as NSDictionary
        }
    }
}
