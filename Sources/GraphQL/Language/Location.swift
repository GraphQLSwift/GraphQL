import Foundation

public struct SourceLocation: Codable, Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/**
 * Takes a Source and a UTF-8 character offset, and returns the corresponding
 * line and column as a SourceLocation.
 */
func getLocation(source: Source, position: Int) -> SourceLocation {
    var line = 1
    var column = position + 1

    do {
        let regex = try NSRegularExpression(pattern: "\r\n|[\n\r]", options: [])
        let matches = regex.matches(
            in: source.body,
            options: [],
            range: NSRange(0 ..< source.body.utf16.count)
        )
        for match in matches where match.range.location < position {
            line += 1
            column = position + 1 - (match.range.location + match.range.length)
        }
    } catch {
        // Leave line and position unset if regex fails
    }

    return SourceLocation(line: line, column: column)
}
