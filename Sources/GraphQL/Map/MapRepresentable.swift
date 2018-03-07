import Runtime

public func map(from value: Any?) throws -> Map {
    guard let value = value else {
        return .null
    }

    if let mapRepresentable = value as? MapRepresentable {
        return mapRepresentable.map
    }

    if let mapFallibleRepresentable = value as? MapFallibleRepresentable {
        return try mapFallibleRepresentable.asMap()
    }
    
    let info = try typeInfo(of: type(of: value))
    let props = info.properties

    var dictionary = [String: Map](minimumCapacity: props.count)

    for property in props {
        dictionary[property.name] = try map(from: property.get(from: value))
    }

    return .dictionary(dictionary)
}

public func assertMappable(_ type: Any.Type) throws {
    if type is MapRepresentable.Type {
        return
    }

    if type is MapFallibleRepresentable.Type {
        return
    }

    let info = try typeInfo(of: type)
    for property in info.properties {
        try assertMappable(property.type)
    }
}

extension MapFallibleRepresentable {
    public func asMap() throws -> Map {
        let info = try typeInfo(of: type(of: self))
        let props = info.properties
        var dictionary = [String: Map](minimumCapacity: props.count)
        for property in props {
            guard let representable = try property.get(from: self) as? MapFallibleRepresentable else {
                throw MapError.notMapRepresentable(property.type)
            }
            dictionary[property.name] = try representable.asMap()
        }
        return .dictionary(dictionary)
    }
}

extension Map : MapRepresentable {
    public var map: Map {
        return self
    }
}

extension Bool : MapRepresentable {
    public var map: Map {
        return .bool(self)
    }
}

extension Double : MapRepresentable {
    public var map: Map {
        return .double(self)
    }
}

extension Int : MapRepresentable {
    public var map: Map {
        return .int(self)
    }
}

extension String : MapRepresentable {
    public var map: Map {
        return .string(self)
    }
}

extension Optional where Wrapped : MapRepresentable {
    public var map: Map {
        switch self {
        case .some(let wrapped): return wrapped.map
        case .none: return .null
        }
    }
}

extension Array where Element : MapRepresentable {
    public var mapArray: [Map] {
        return self.map({$0.map})
    }

    public var map: Map {
        return .array(mapArray)
    }
}

public protocol MapDictionaryKeyRepresentable {
    var mapDictionaryKey: String { get }
}

extension String : MapDictionaryKeyRepresentable {
    public var mapDictionaryKey: String {
        return self
    }
}

extension Dictionary where Key : MapDictionaryKeyRepresentable, Value : MapRepresentable {
    public var mapDictionary: [String: Map] {
        var dictionary: [String: Map] = [:]

        for (key, value) in self.map({($0.0.mapDictionaryKey, $0.1.map)}) {
            dictionary[key] = value
        }

        return dictionary
    }

    public var map: Map {
        return .dictionary(mapDictionary)
    }
}

// MARK: MapFallibleRepresentable

extension Optional : MapFallibleRepresentable {
    public func asMap() throws -> Map {
        if case .some(let wrapped as MapFallibleRepresentable) = self {
            return try GraphQL.map(from: wrapped)
        }
        return .null
    }
}

extension Array : MapFallibleRepresentable {
    public func asMap() throws -> Map {
        var array: [Map] = []
        array.reserveCapacity(count)

        if Element.self is MapFallibleRepresentable.Type {
            for value in self {
                let value = value as! MapFallibleRepresentable
                array.append(try value.asMap())
            }
        } else {
            for value in self {
                if let value = value as? MapRepresentable {
                    array.append(value.map)
                } else if let value = value as? MapFallibleRepresentable {
                    array.append(try value.asMap())
                } else {
                    throw MapError.notMapRepresentable(type(of: value))
                }
            }
        }

        return .array(array)
    }
}

extension Dictionary : MapFallibleRepresentable {
    public func asMap() throws -> Map {
        guard Key.self is MapDictionaryKeyRepresentable.Type else {
            throw MapError.notMapDictionaryKeyRepresentable(Value.self)
        }

        var dictionary = [String: Map](minimumCapacity: count)

        if Value.self is MapFallibleRepresentable.Type {
            for (key, value) in self {
                let value = value as! MapFallibleRepresentable
                let key = key as! MapDictionaryKeyRepresentable
                dictionary[key.mapDictionaryKey] = try value.asMap()
            }
        } else {
            for (key, value) in self {
                let key = key as! MapDictionaryKeyRepresentable
                if let value = value as? MapRepresentable {
                    dictionary[key.mapDictionaryKey] = value.map
                } else if let value = value as? MapFallibleRepresentable {
                    dictionary[key.mapDictionaryKey] = try value.asMap()
                } else {
                    throw MapError.notMapRepresentable(type(of: value))
                }
            }
        }
        
        return .dictionary(dictionary)
    }
}
