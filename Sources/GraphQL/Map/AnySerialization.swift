import Foundation

public enum AnySerialization {
    static func map(with object: NSObject) throws -> Any {
        return object
    }

    static func object(with map: Any) throws -> NSObject {
        guard let result = map as? NSObject else {
            throw EncodingError.invalidValue(
                map,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Expected object input to be castable to NSObject: \(type(of: map))"
                )
            )
        }
        return result
    }
}
