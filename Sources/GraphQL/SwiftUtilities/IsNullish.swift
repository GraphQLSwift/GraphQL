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
//func isNullish(_ value: Any?) -> Bool {
//    guard value != nil else {
//        return true
//    }
//
//    return false
//}
