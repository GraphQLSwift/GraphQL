import Foundation

/**
 * Print a block string in the indented block form by adding a leading and
 * trailing blank line. However, if a block string starts with whitespace and is
 * a single-line, adding a leading blank line would strip that whitespace.
 *
 * @internal
 */
func printBlockString(
    _ value: String,
    minimize: Bool = false
) -> String {
    let escapedValue = value.replacingOccurrences(of: "\"\"\"", with: "\\\"\"\"")

    // Expand a block string's raw value into independent lines.
    let lines = splitLines(string: escapedValue)
    let isSingleLine = lines.count == 1

    // If common indentation is found we can fix some of those cases by adding leading new line
    let forceLeadingNewLine =
        lines.count > 1 &&
        lines[1 ... (lines.count - 1)].allSatisfy { line in
            line.count == 0 || isWhiteSpace(line.charCode(at: 0))
        }

    // Trailing triple quotes just looks confusing but doesn't force trailing new line
    let hasTrailingTripleQuotes = escapedValue.hasSuffix("\\\"\"\"")

    // Trailing quote (single or double) or slash forces trailing new line
    let hasTrailingQuote = value.hasSuffix("\"") && !hasTrailingTripleQuotes
    let hasTrailingSlash = value.hasSuffix("\\")
    let forceTrailingNewline = hasTrailingQuote || hasTrailingSlash

    let printAsMultipleLines =
        !minimize &&
        // add leading and trailing new lines only if it improves readability
        (
            !isSingleLine ||
                value.count > 70 ||
                forceTrailingNewline ||
                forceLeadingNewLine ||
                hasTrailingTripleQuotes
        )

    var result = ""

    // Format a multi-line block quote to account for leading space.
    let skipLeadingNewLine = isSingleLine && isWhiteSpace(value.charCode(at: 0))
    if (printAsMultipleLines && !skipLeadingNewLine) || forceLeadingNewLine {
        result += "\n"
    }

    result += escapedValue
    if printAsMultipleLines || forceTrailingNewline {
        result += "\n"
    }

    return "\"\"\"" + result + "\"\"\""
}
