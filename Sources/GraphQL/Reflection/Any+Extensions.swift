//
//  Any+Extensions.swift
//  Reflection
//
//  Created by Bradley Hilton on 10/17/16.
//
//

public protocol AnyExtensions {}

public extension AnyExtensions {
    
    static func construct(constructor: (Property.Description) throws -> Any) throws -> Any {
        return try GraphQL.construct(self, constructor: constructor)
    }
    
    static func construct(dictionary: [String: Any]) throws -> Any {
        return try GraphQL.construct(self, dictionary: dictionary)
    }
    
    func write(to pointer: UnsafeMutableRawPointer) {
        pointer.assumingMemoryBound(to: type(of: self)).initialize(to: self)
    }
    
}

public func extensions(of type: Any.Type) -> AnyExtensions.Type {
    struct Extensions : AnyExtensions {}
    var extensions: AnyExtensions.Type = Extensions.self
    withUnsafePointer(to: &extensions) { pointer in
        UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Any.Type.self).pointee = type
    }
    return extensions
}

public func extensions(of value: Any) -> AnyExtensions {
    struct Extensions : AnyExtensions {}
    var extensions: AnyExtensions = Extensions()
    withUnsafePointer(to: &extensions) { pointer in
        UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Any.self).pointee = value
    }
    return extensions
}
