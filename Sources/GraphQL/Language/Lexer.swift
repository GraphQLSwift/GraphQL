/**
 * Given a Source object, this returns a Lexer for that source.
 * A Lexer is a stateful stream generator in that every time
 * it is advanced, it returns the next token in the Source. Assuming the
 * source lexes, the final Token emitted by the lexer will be of kind
 * EOF, after which the lexer will repeatedly return the same EOF token
 * whenever called.
 */
func createLexer(source: Source, noLocation: Bool = false) -> Lexer {
    let startOfFileToken = Token(
        kind: .sof,
        start: 0,
        end: 0,
        line: 0,
        column: 0,
        value: nil
    )

    let lexer: Lexer = Lexer(
        source: source,
        noLocation: noLocation,
        lastToken: startOfFileToken,
        token: startOfFileToken,
        line: 1,
        lineStart: 0,
        advance: advanceLexer
    )

    return lexer
}

func advanceLexer(lexer: Lexer) throws -> Token {
    lexer.lastToken = lexer.token
    var token = lexer.lastToken

      if token.kind != .eof {
        repeat {
            token.next = try readToken(lexer: lexer, prev: token)
            token = token.next!
        } while token.kind == .comment

        lexer.token = token
      }

    return token
}

/**
 * The return type of createLexer.
 */
final class Lexer {
    let source: Source
    let noLocation: Bool

    /**
     * The previously focused non-ignored token.
     */
    var lastToken: Token

    /**
     * The currently focused non-ignored token.
     */
    var token: Token

    /**
     * The (1-indexed) line containing the current token.
     */
    var line: Int

    /**
     * The character offset at which the current line begins.
     */
    var lineStart: Int

    /**
     * Advances the token stream to the next non-ignored token.
     */
    let advanceFunction: (Lexer) throws -> Token

    init(source: Source, noLocation: Bool, lastToken: Token, token: Token, line: Int, lineStart: Int, advance: @escaping (Lexer) throws -> Token) {
        self.source = source
        self.noLocation = noLocation
        self.lastToken = lastToken
        self.token = token
        self.line = line
        self.lineStart = lineStart
        self.advanceFunction = advance
    }

    @discardableResult
    func advance() throws -> Token {
        return try advanceFunction(self)
    }
}

/**
 * A helper function to describe a token as a string for debugging
 */
func getTokenDesc(_ token: Token) -> String {
    if let value = token.value {
        return "\(token.kind) \"\(value)\""
    }

    return "\(token.kind)"
}

extension String {
    func charCode(at position: Int) -> UInt8? {
        guard position < utf8.count else {
            return nil
        }
        return utf8[utf8.index(utf8.startIndex, offsetBy: position)]
    }

    func slice(start: Int, end: Int) -> String {
        let startIndex = utf8.index(utf8.startIndex, offsetBy: start)
        let endIndex = utf8.index(utf8.startIndex, offsetBy: end)
        var slice: [UInt8] = utf8[startIndex..<endIndex] + [0]
        return String(cString: &slice)
    }
}

func character(_ code: UInt8) -> Character {
  return Character(UnicodeScalar(code))
}

/**
 * Gets the next token from the source starting at the given position.
 *
 * This skips over whitespace and comments until it finds the next lexable
 * token, then lexes punctuators immediately or calls the appropriate helper
 * function for more complicated tokens.
 */
func readToken(lexer: Lexer, prev: Token) throws -> Token {
    let source = lexer.source
    let body = source.body
    let bodyLength = body.utf8.count

    let position = positionAfterWhitespace(body: body, startPosition: prev.end, lexer: lexer)
    let line = lexer.line
    let col = 1 + position - lexer.lineStart

    if position >= bodyLength {
        return Token(
            kind: .eof,
            start: bodyLength,
            end: bodyLength,
            line: line,
            column: col,
            prev: prev
        )
    }

    guard let code = body.charCode(at: position) else {
        throw syntaxError(
            source: source,
            position: position,
            description: "Unexpected character <EOF>."
        )
    }

    // SourceCharacter
    if code < 0x0020 && code != 0x0009 && code != 0x000A && code != 0x000D {
        throw syntaxError(
            source: source,
            position: position,
            description: "Invalid character \(character(code))."
        )
    }

    switch code {
    // !
    case 33:
        return Token(
            kind: .bang,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // #
    case 35:
        return readComment(
            source: source,
            start: position,
            line: line,
            col: col,
            prev: prev
        )
    // $
    case 36:
        return Token(
            kind: .dollar,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // (
    case 40:
        return Token(
            kind: .openingParenthesis,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // )
    case 41:
        return Token(
            kind: .closingParenthesis,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // .
    case 46:
      if body.charCode(at: position + 1) == 46 && body.charCode(at: position + 2) == 46 {
        return Token(
            kind: .spread,
            start: position,
            end: position + 3,
            line: line,
            column: col,
            prev: prev
        )
      }
    // :
    case 58:
        return Token(
            kind: .colon,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // =
    case 61:
        return Token(
            kind: .equals,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // @
    case 64:
        return Token(
            kind: .at,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // [
    case 91:
        return Token(
            kind: .openingBracket,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // ]
    case 93:
        return Token(
            kind: .closingBracket,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // {
    case 123:
        return Token(
            kind: .openingBrace,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // |
    case 124:
        return Token(
            kind: .pipe,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // }
    case 125:
        return Token(
            kind: .closingBrace,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // A-Z _ a-z
    case 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 95, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122:
        return readName(
            source: source,
            position: position,
            line: line,
            col: col,
            prev: prev)
    // - 0-9
    case 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
        return try readNumber(
            source: source,
            start: position,
            firstCode: code,
            line: line,
            col: col,
            prev: prev
        )
    // "
    case 34:
        return try readString(
            source: source,
            start: position,
            line: line,
            col: col,
            prev: prev
        )
    default:
        break
    }

    throw syntaxError(
        source: source,
        position: position,
        description: "Unexpected character \(character(code))."
    )
}

/**
 * Reads from body starting at startPosition until it finds a non-whitespace
 * or commented character, then returns the position of that character for
 * lexing.
 */
func positionAfterWhitespace(body: String, startPosition: Int, lexer: Lexer) -> Int {
    let bodyLength = body.utf8.count
    var position = startPosition

    while position < bodyLength {
        let code = body.charCode(at: position)

        // BOM
        if code == 239 && body.charCode(at: position + 1) == 187 && body.charCode(at: position + 2) == 191 {
            position += 3
        } else if code == 9 || code == 32 || code == 44 { // tab | space | comma
            position += 1
        } else if code == 10 { // new line
            position += 1
            lexer.line += 1
            lexer.lineStart = position
        } else if code == 13 { // carriage return
            if body.charCode(at: position + 1) == 10 {
                position += 2
            } else {
                position += 1
            }
            lexer.line += 1
            lexer.lineStart = position
        } else {
            break
        }
    }

    return position
}

/**
 * Reads a comment token from the source file.
 *
 * #[\u0009\u0020-\uFFFF]*
 */
func readComment(source: Source, start: Int, line: Int, col: Int, prev: Token) -> Token {
    let body = source.body
    var code: UInt8?
    var position = start

    while true {
        position += 1
        code = body.charCode(at: position)

        // SourceCharacter but not LineTerminator
        if let code = code, (code > 0x001F || code == 0x0009) {
            continue
        } else {
            break
        }
    }

    return Token(
        kind: .comment,
        start: start,
        end: position,
        line: line,
        column: col,
        value: body.slice(start: start + 1, end: position),
        prev: prev
    )
}

/**
 * Reads a number token from the source file, either a float
 * or an int depending on whether a decimal point appears.
 *
 * Int:   -?(0|[1-9][0-9]*)
 * Float: -?(0|[1-9][0-9]*)(\.[0-9]+)?((E|e)(+|-)?[0-9]+)?
 */
func readNumber(source: Source, start: Int, firstCode: UInt8, line: Int, col: Int, prev: Token) throws -> Token {
    let body = source.body
    var code: UInt8? = firstCode
    var position = start
    var isFloat = false

    if let c = code, c == 45 { // -
        position += 1
        code = body.charCode(at: position)
    }

    if let c = code, c == 48 { // 0
        position += 1
        code = body.charCode(at: position)

        if let c = code, c >= 48 && c <= 57 {
            throw syntaxError(
                source: source,
                position: position,
                description: "Invalid number, unexpected digit after 0: \(character(c))."
            )
        }
    } else if let c = code {
        position = try readDigits(source: source, start: position, firstCode: c)
        code = body.charCode(at: position)
    }

    if let c = code, c == 46 { // .
        isFloat = true
        position += 1
        code = body.charCode(at: position)

        if let c = code {
            position = try readDigits(source: source, start: position, firstCode: c)
            code = body.charCode(at: position)
        } else {
            throw syntaxError(
                source: source,
                position: position,
                description: "Invalid number, expected digit but got: <EOF>."
            )
        }
    }

    if let c = code, c == 69 || c == 101 { // E e
        isFloat = true
        position += 1
        code = body.charCode(at: position)

        if let c = code, c == 43 || c == 45 { // + -
            position += 1
            code = body.charCode(at: position)
        }

        if let c = code {
            position = try readDigits(source: source, start: position, firstCode: c)
        } else {
            throw syntaxError(
                source: source,
                position: position,
                description: "Invalid number, expected digit but got: <EOF>."
            )
        }
    }

    return Token(
        kind: isFloat ? .float : .int,
        start: start,
        end: position,
        line: line,
        column: col,
        value: body.slice(start: start, end: position),
        prev: prev
    )
}

/**
 * Returns the new position in the source after reading digits.
 */
func readDigits(source: Source, start: Int, firstCode: UInt8) throws -> Int {
    let body = source.body
    var position = start

    if firstCode >= 48 && firstCode <= 57 { // 0 - 9
        while true {
            position += 1
            if let code = body.charCode(at: position), code >= 48 && code <= 57 { // 0 - 9
                continue
            } else {
                break
            }
        }

        return position
    }

    throw syntaxError(
        source: source,
        position: position,
        description: "Invalid number, expected digit but got: \(character(firstCode))."
    )
}

/**
 * Reads a string token from the source file.
 *
 * "([^"\\\u000A\u000D]|(\\(u[0-9a-fA-F]{4}|["\\/bfnrt])))*"
 */
func readString(source: Source, start: Int, line: Int, col: Int, prev: Token) throws -> Token {
    let body = source.body
    let bodyLength = body.utf8.count
    var position = start + 1
    var chunkStart = position
    var currentCode: UInt8? = 0
    var value = ""

    while position < bodyLength {
        currentCode = body.charCode(at: position)

        //                     not LineTerminator                  not Quote (")
        guard let code = currentCode, code != 0x000A && code != 0x000D && code != 34 else {
            break
        }

        // SourceCharacter
        if code < 0x0020 && code != 0x0009 {
            throw syntaxError(
                source: source,
                position: position,
                description: "Invalid character within String: \(character(code))."
            )
        }

        position += 1

        if code == 92 { // \
            value += body.slice(start: chunkStart, end: position - 1)
            currentCode = body.charCode(at: position)

            if let code = currentCode {
                switch code {
                case 34: value += "\""
                case 47: value += "/"
                case 92: value += "\\"
                case 98: value += "\u{8}"
                case 102: value += "\u{12}"
                case 110: value += "\n"
                case 114: value += "\r"
                case 116: value += "\t"
                case 117: // u
                    let charCode = uniCharCode(
                        a: body.charCode(at: position + 1)!,
                        b: body.charCode(at: position + 2)!,
                        c: body.charCode(at: position + 3)!,
                        d: body.charCode(at: position + 4)!
                    )

                    if charCode < 0 {
                        throw syntaxError(
                            source: source,
                            position: position,
                            description:
                            "Invalid character escape sequence: " +
                            "\\u\(body.slice(start: position + 1, end: position + 5))."
                        )
                    }

                    value += String(Character(UnicodeScalar(UInt32(charCode))!))
                    position += 4
                default:
                    throw syntaxError(
                        source: source,
                        position: position,
                        description: "Invalid character escape sequence: \\\(character(code))."
                    )
                }
            }

            position += 1
            chunkStart = position
        }
    }

    if currentCode != 34 { // quote (")
        throw syntaxError(
            source: source,
            position: position,
            description: "Unterminated string."
        )
    }

    value += body.slice(start: chunkStart, end: position)

    return Token(
        kind: .string,
        start: start,
        end: position + 1,
        line: line,
        column: col,
        value: value,
        prev: prev
    )
}

/**
 * Converts four hexidecimal chars to the integer that the
 * string represents. For example, uniCharCode('0','0','0','f')
 * will return 15, and uniCharCode('0','0','f','f') returns 255.
 *
 * Returns a negative number on error, if a char was invalid.
 *
 * This is implemented by noting that char2hex() returns -1 on error,
 * which means the result of ORing the char2hex() will also be negative.
 */
func uniCharCode(a: UInt8, b: UInt8, c: UInt8, d: UInt8) -> Int {
  return char2hex(a) << 12 | char2hex(b) << 8 | char2hex(c) << 4 | char2hex(d)
}

/**
 * Converts a hex character to its integer value.
 * '0' becomes 0, '9' becomes 9
 * 'A' becomes 10, 'F' becomes 15
 * 'a' becomes 10, 'f' becomes 15
 *
 * Returns -1 on error.
 */
func char2hex(_ a: UInt8) -> Int {
    let a = Int(a)
    return a >= 48 && a <= 57 ? a - 48 : // 0-9
           a >= 65 && a <= 70 ? a - 55 : // A-F
           a >= 97 && a <= 102 ? a - 87 : // a-f
           -1
}

/**
 * Reads an alphanumeric + underscore name from the source.
 *
 * [_A-Za-z][_0-9A-Za-z]*
 */
func readName(source: Source, position: Int, line: Int, col: Int, prev: Token) -> Token {
    let body = source.body
    let bodyLength = body.utf8.count
    var end = position + 1

    while end != bodyLength,
          let code = body.charCode(at: end),
          (code == 95 || // _
           code >= 48 && code <= 57 || // 0-9
           code >= 65 && code <= 90 || // A-Z
           code >= 97 && code <= 122) { // a-z
        end += 1
    }

    return Token(
        kind: .name,
        start: position,
        end: end,
        line: line,
        column: col,
        value: body.slice(start: position, end: end),
        prev: prev
    )
}
