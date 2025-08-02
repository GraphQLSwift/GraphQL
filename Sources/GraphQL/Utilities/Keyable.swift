public protocol KeySubscriptable {
    subscript(_: String) -> (any Sendable)? { get }
}
