import Foundation

public struct AnySerialization {
    static func map(with object: NSObject) throws -> Any {
        return object
    }
    
    static func object(with map: Any) throws -> NSObject {
        return map as! NSObject
    }
}
