/**
 * ```
 * WhiteSpace ::
 *   - "Horizontal Tab (U+0009)"
 *   - "Space (U+0020)"
 * ```
 * @internal
 */
func isWhiteSpace(_ code: UInt8?) -> Bool {
    guard let code = code else {
        return false
    }
    return code == 0x0009 || code == 0x0020
}
