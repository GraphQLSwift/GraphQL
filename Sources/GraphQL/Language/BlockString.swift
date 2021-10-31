/**
 * Print a block string in the indented block form by adding a leading and
 * trailing blank line. However, if a block string starts with whitespace and is
 * a single-line, adding a leading blank line would strip that whitespace.
 *
 * @internal
 */
func printBlockString(
    value: String,
    preferMultipleLines: Bool = false
) -> String {
    let isSingleLine = !value.contains("\n")
    let hasLeadingSpace = value.hasPrefix(" ") || value.hasPrefix("\t")
    let hasTrailingQuote = value.hasSuffix("\"")
    let hasTrailingSlash = value.hasSuffix("\\")

    let printAsMultipleLines =
        !isSingleLine ||
        hasTrailingQuote ||
        hasTrailingSlash ||
        preferMultipleLines

    var result = ""

    // Format a multi-line block quote to account for leading space.
    if printAsMultipleLines, !(isSingleLine && hasLeadingSpace) {
        result += "\n"
    }

    result += value

    if printAsMultipleLines {
        result += "\n"
    }

    return
        "\"\"\"" +
        result.replacingOccurrences(of: "\"\"\"", with: "\\\"\"\"") +
        "\"\"\""
}
