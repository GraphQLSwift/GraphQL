func invariant(condition: Bool, message: String) throws {
    struct Error : Swift.Error, CustomStringConvertible {
        let description: String
    }

    if !condition {
        throw Error(description: message)
    }
}
