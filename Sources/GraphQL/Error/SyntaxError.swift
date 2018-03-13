import Foundation

/**
 * Produces a GraphQLError representing a syntax error, containing useful
 * descriptive information about the syntax error's position in the source.
 */
func syntaxError(source: Source, position: Int, description: String) -> GraphQLError {
    let location = getLocation(source: source, position: position)

    let error = GraphQLError(
        message:
        "Syntax Error \(source.name) (\(location.line):\(location.column)) " +
        description + "\n\n" +
        highlightSourceAtLocation(source: source, location: location),
        source: source,
        positions: [position]
    )

    return error
}

/**
 * Render a helpful description of the location of the error in the GraphQL
 * Source document.
 */
func highlightSourceAtLocation(source: Source, location: SourceLocation) -> String {
    let line = location.line
    let prevLineNum = (line - 1).description
    let lineNum = line.description
    let nextLineNum = (line + 1).description
    let padLength = nextLineNum.count

    let lines = splitLines(string: source.body)

    var string = ""

    if line >= 2 {
        string += leftpad(padLength, prevLineNum) + ": " + lines[line - 2] + "\n"
    }

    string += leftpad(padLength, lineNum) + ": " + lines[line - 1] + "\n"
    string += String(repeating: " ", count: max(2 + padLength + location.column, 0)) + "^\n"

    if line < lines.count {
        string += leftpad(padLength, nextLineNum) + ": " + lines[line] + "\n"
    }

    return string
}

func splitLines(string: String) -> [String] {

    let nsstring = NSString(string: string)
    let regex = try! NSRegularExpression(pattern: "\r\n|[\n\r]", options: [])

    var lines: [String] = []
    var location = 0

    for match in regex.matches(in: string, options: [], range: NSRange(0..<nsstring.length)) {
        let range = NSRange(location..<match.range.location)
        lines.append(nsstring.substring(with: range))
        location =  match.range.location + match.range.length
    }

    if lines.isEmpty {
        return [string]
    } else {
        let range = NSRange(location..<nsstring.length)
        lines.append(nsstring.substring(with: range))
    }

    return lines
}

func leftpad(_ length: Int, _ string: String) -> String {
    return String(repeating: " ", count: max(length - string.count + 1, 0)) + string
}
