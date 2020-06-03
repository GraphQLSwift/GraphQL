import Foundation

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
                try self.map(with: value as! NSObject)
            }
            
            return .array(array)
        case let dictionary as NSDictionary:
            let dictionary: [String : Map] = try dictionary.reduce(into: [:]) { (dictionary, pair) in
                dictionary[pair.key as! String] = try self.map(with: pair.value as! NSObject)
            }
            
            return .dictionary(dictionary)
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
            return try dictionary.mapValues({ try object(with: $0) }) as NSDictionary
        }
    }
}
