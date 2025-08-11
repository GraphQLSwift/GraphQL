func unwrap(_ value: any Sendable) -> (any Sendable)? {
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle != .optional {
        return value
    }

    guard let child = mirror.children.first else {
        return nil
    }

    // Despite the warning, we must force unwrap because on optional unwrap, compiler throws:
    // `marker protocol 'Sendable' cannot be used in a conditional cast`
    return (child.value as! (any Sendable))
}

extension Mirror {
    func getValue(named key: String) -> (any Sendable)? {
        guard let matched = children.filter({ $0.label == key }).first else {
            return nil
        }

        // Despite the warning, we must force unwrap because on optional unwrap, compiler throws:
        // `marker protocol 'Sendable' cannot be used in a conditional cast`
        return unwrap(matched.value as! (any Sendable))
    }
}
