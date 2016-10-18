struct SourceLocation {
    let line: Int
    let column: Int
}

extension Source {
    /**
     * Takes a Source and a UTF-8 character offset, and returns the corresponding
     * line and column as a SourceLocation.
     */
    func getLocation(position: Int) -> SourceLocation {
//        let lineRegexp = "/\r\n|[\n\r]/g"
//        var line = 1
//        var column = position + 1
//        var match;
//
//        while ((match = lineRegexp.exec(self.body)) && match.index < position) {
//            line += 1
//            column = position + 1 - (match.index + match[0].length)
//        }

        return SourceLocation(line: 0, column: 0)
    }
}
