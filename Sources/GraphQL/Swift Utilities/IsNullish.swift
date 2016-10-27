protocol OptionalProtocol {
    var wrappedType: Any.Type { get }
    var isNil: Bool { get }
}

extension Optional : OptionalProtocol {
    var wrappedType: Any.Type {
        return Wrapped.self
    }

    var isNil: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}

/**
 * Returns true if a value is null, or nil.
 */
func isNullish(_ value: MapRepresentable?) -> Bool {
    guard let value = value else {
        return true
    }

    if let value = value as? Map {
        return value == .null
    }

    if let value = value as? OptionalProtocol, value.isNil {
        return true
    }

    // TODO: maybe unwrap a Map inside an Optional and check for .null

    return false
}
