/**
 * Returns true if a value is null, undefined, or NaN.
 */
func isNullish(_ value: Map?) -> Bool {
    guard let value = value else {
        return true
    }
    return value == .null
}
