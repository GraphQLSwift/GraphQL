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

public protocol MapDictionaryKeyRepresentable {
    var mapDictionaryKey: String { get }
}

extension String : MapDictionaryKeyRepresentable {
    public var mapDictionaryKey: String {
        return self
    }
}

// MARK: MapFallibleRepresentable

extension Optional : MapFallibleRepresentable {
    public func asMap() throws -> Map {
        guard Wrapped.self is MapFallibleRepresentable.Type else {
            throw MapError.notMapRepresentable(Wrapped.self)
        }
        if case .some(let wrapped as MapFallibleRepresentable) = self {
            return try wrapped.asMap()
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

// Unsafe Stuff

// TODO: Use conditional conformances
extension Optional : MapRepresentable {
    public var map: Map {
        guard Wrapped.self is MapRepresentable.Type else {
            return .null
        }
        if case .some(let wrapped as MapRepresentable) = self {
            return wrapped.map
        }
        return .null
    }
}

extension Array : MapRepresentable {
    public var map: Map {
        var array: [Map] = []
        array.reserveCapacity(count)

        if Element.self is MapRepresentable.Type {
            for value in self {
                let value = value as! MapRepresentable
                array.append(value.map)
            }
        } else {
            for value in self {
                if let value = value as? MapRepresentable {
                    array.append(value.map)
                } else {
                    return .null
                }
            }
        }

        return .array(array)
    }
}

extension Dictionary : MapRepresentable {
    public var map: Map {
        guard Key.self is MapDictionaryKeyRepresentable.Type else {
            return .null
        }

        var dictionary = [String: Map](minimumCapacity: count)

        if Value.self is MapRepresentable.Type {
            for (key, value) in self {
                let value = value as! MapRepresentable
                let key = key as! MapDictionaryKeyRepresentable
                dictionary[key.mapDictionaryKey] = value.map
            }
        } else {
            for (key, value) in self {
                let key = key as! MapDictionaryKeyRepresentable
                if let value = value as? MapRepresentable {
                    dictionary[key.mapDictionaryKey] = value.map
                }  else {
                    return .null
                }
            }
        }

        return .dictionary(dictionary)
    }
}
