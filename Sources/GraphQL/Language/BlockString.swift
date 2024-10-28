import Foundation

func isPrintableAsBlockString(_ value: String) -> Bool {
    if value == "" {
        return true // empty string is printable
    }

    var isEmptyLine = true
    var hasIndent = false
    var hasCommonIndent = true
    var seenNonEmptyLine = false

    let scalars = Array(value.unicodeScalars)
    for i in 0 ..< scalars.count {
        switch scalars[i].value {
        case 0x0000,
             0x0001,
             0x0002,
             0x0003,
             0x0004,
             0x0005,
             0x0006,
             0x0007,
             0x0008,
             0x000B,
             0x000C,
             0x000E,
             0x000F:
            return false // Has non-printable characters

        case 0x000D: //  \r
            return false // Has \r or \r\n which will be replaced as \n

        case 10: //  \n
            if isEmptyLine && !seenNonEmptyLine {
                return false // Has leading new line
            }
            seenNonEmptyLine = true

            isEmptyLine = true
            hasIndent = false

        case 9, //   \t
             32: //  <space>
            if !hasIndent {
                hasIndent = isEmptyLine
            }

        default:
            if hasCommonIndent {
                hasCommonIndent = hasIndent
            }
            isEmptyLine = false
        }
    }

    if isEmptyLine {
        return false // Has trailing empty lines
    }

    if hasCommonIndent && seenNonEmptyLine {
        return false // Has internal indent
    }

    return true
}

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
