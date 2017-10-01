/// Create a struct with a constructor method. Return a value of `property.type` for each property.
public func construct<T>(_ type: T.Type = T.self, constructor: (Property.Description) throws -> Any) throws -> T {
    return try constructGenericType(constructor: constructor)
}

func constructGenericType<T>(_ type: T.Type = T.self, constructor: (Property.Description) throws -> Any) throws -> T {
    if Metadata(type: T.self)?.kind == .struct {
        return try constructValueType(constructor)
    } else {
        throw ReflectionError.notStruct(type: T.self)
    }
}

/// Create a struct with a constructor method. Return a value of `property.type` for each property.
public func construct(_ type: Any.Type, constructor: (Property.Description) throws -> Any) throws -> Any {
    return try extensions(of: type).construct(constructor: constructor)
}

private func constructValueType<T>(_ constructor: (Property.Description) throws -> Any) throws -> T {
    guard Metadata(type: T.self)?.kind == .struct else { throw ReflectionError.notStruct(type: T.self) }
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { pointer.deallocate(capacity: 1) }
    var values: [Any] = []
    try constructType(storage: UnsafeMutableRawPointer(pointer), values: &values, properties: properties(T.self), constructor: constructor)
    return pointer.move()
}

private func constructType(storage: UnsafeMutableRawPointer, values: inout [Any], properties: [Property.Description], constructor: (Property.Description) throws -> Any) throws {
    var errors = [Error]()
    for property in properties {
        do {
            let value = try constructor(property)
            values.append(value)
            try property.write(value, to: storage)
        } catch {
            errors.append(error)
        }
    }
    if errors.count > 0 {
        throw ConstructionErrors(errors: errors)
    }
}

/// Create a struct from a dictionary.
public func construct<T>(_ type: T.Type = T.self, dictionary: [String: Any]) throws -> T {
    return try constructGenericType(constructor: constructorForDictionary(dictionary))
}

/// Create a struct from a dictionary.
public func construct(_ type: Any.Type, dictionary: [String: Any]) throws -> Any {
    return try construct(type, constructor: constructorForDictionary(dictionary))
}

private func constructorForDictionary(_ dictionary: [String: Any]) -> (Property.Description) throws -> Any {
    return { property in
        if let value = dictionary[property.key] {
            return value
        } else if let expressibleByNilLiteral = property.type as? ExpressibleByNilLiteral.Type {
            return expressibleByNilLiteral.init(nilLiteral: ())
        } else {
            throw ReflectionError.requiredValueMissing(key: property.key)
        }
    }
}
