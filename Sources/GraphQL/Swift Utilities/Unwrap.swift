public func unwrap(_ value: Any) -> MapFallibleRepresentable? {
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle != .optional {
        return value as? MapFallibleRepresentable
    }

    if mirror.children.isEmpty {
        return nil
    }

    let child = mirror.children.first!
    return child.value as? MapFallibleRepresentable
}
