import Foundation

public typealias SourceLocation = (line: Int, column: Int)

/**
 * Takes a Source and a UTF-8 character offset, and returns the corresponding
 * line and column as a SourceLocation.
 */
func getLocation(source: Source, position: Int) -> SourceLocation {
    var line = 1
    var column = position + 1

    let regex = try! NSRegularExpression(pattern: "\r\n|[\n\r]", options: [])

    let matches = regex.matches(in: source.body, options: [], range: NSRange(0..<source.body.utf16.count))

    for match in matches where match.range.location < position {
        line += 1
        column = position + 1 - (match.range.location + match.range.length)
    }

    return SourceLocation(line: line, column: column)
}
