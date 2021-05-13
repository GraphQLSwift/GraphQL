func unwrap(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle != .optional {
        return value
    }

    guard let child = mirror.children.first else {
        return nil
    }

    return child.value
}

extension Mirror {
    func getValue(named key: String) -> Any? {
        guard let matched = children.filter({ $0.label == key }).first else {
            return nil
        }
        return unwrap(matched.value)
    }
}
