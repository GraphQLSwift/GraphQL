import XCTest
@testable import GraphQL

func lexOne(_ string: String) throws -> Token {
    let lexer = createLexer(source: Source(body: string))
    return try lexer.advance()
}

class LexerTests : XCTestCase {
    func testInvalidCharacter() throws {
        XCTAssertThrowsError(try lexOne("\u{0007}"))
//        'Syntax Error GraphQL (1:1) Invalid character "\\u0007"'
    }

    func testBOMHeader() throws {
        let token = try lexOne("\u{FEFF} foo")

        let expected = Token(
            kind: .name,
            start: 4,
            end: 7,
            line: 1,
            column: 5, // TODO: Ignore BOM when counting characters making this 2.
            value: "foo"
        )

        XCTAssertEqual(token, expected)
    }

    func testRecordsLineAndColumn() throws {
        let token = try lexOne("\n \r\n \r  foo\n")

        let expected = Token(
            kind: .name,
            start: 8,
            end: 11,
            line: 4,
            column: 3,
            value: "foo"
        )

        XCTAssertEqual(token, expected)
    }

    func testTokenDescription() throws {
        let token = try lexOne("foo")
        let expected = "Token(kind: Name, value: foo, line: 1, column: 1)"
        XCTAssertEqual(token.description, expected)
    }

    func testSkipsWhitespace() throws {
        let token = try lexOne("\n\n    foo\n\n")

        let expected = Token(
            kind: .name,
            start: 6,
            end: 9,
            line: 3,
            column: 5,
            value: "foo"
        )

        XCTAssertEqual(token, expected)
    }

    func testSkipsComments() throws {
        let token = try lexOne("    #comment\r\n    foo#comment")

        let expected = Token(
            kind: .name,
            start: 18,
            end: 21,
            line: 2,
            column: 5,
            value: "foo"
        )

        XCTAssertEqual(token, expected)
    }

    func testSkipsCommas() throws {
        let token = try lexOne(",,,foo,,,")

        let expected = Token(
            kind: .name,
            start: 3,
            end: 6,
            line: 1,
            column: 4,
            value: "foo"
        )

        XCTAssertEqual(token, expected)
    }

    func testErrorsRespectWhitespaces() throws {
        XCTAssertThrowsError(try lexOne("\n\n?\n\n"))
//      'Syntax Error GraphQL (3:5) Unexpected character "?".\n' +
//      '\n' +
//      '2: \n' +
//      '3:     ?\n' +
//      '       ^\n' +
//      '4: \n'
    }

    func testStrings() throws {
        var token: Token
        var expected: Token

        token = try lexOne("\"simple\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 8,
            line: 1,
            column: 1,
            value: "simple"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\"😎\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "😎"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\" white space \"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 15,
            line: 1,
            column: 1,
            value: " white space "
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\"quote \\\"\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 10,
            line: 1,
            column: 1,
            value: "quote \""
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\"escaped \\n\\r\\b\\t\\f\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 20,
            line: 1,
            column: 1,
            value: "escaped \n\r\u{8}\u{9}\u{12}"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\"slashes \\\\\\\\ \\\\/\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 18,
            line: 1,
            column: 1,
            value: "slashes \\\\ \\/"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("\"unicode \\u1234\\u5678\\u90AB\\uCDEF\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 34,
            line: 1,
            column: 1,
            value: "unicode \u{1234}\u{5678}\u{90AB}\u{CDEF}"
        )

        XCTAssertEqual(token, expected)
    }

    func testLongStrings() throws {
        measure {
            let token = try! lexOne("\"\(String(repeating: "123456", count: 10_000))\"")

            XCTAssertEqual(token.start, 0)
            XCTAssertEqual(token.end, 60_002)
        }
    }

    func testStringErrors() throws {
        XCTAssertThrowsError(try lexOne("\""))
        // "Syntax Error GraphQL (1:2) Unterminated string"

        XCTAssertThrowsError(try lexOne("\"contains unescaped \u{0007} control char\""))
        // "Syntax Error GraphQL (1:21) Invalid character within String: "\\u0007"."

        XCTAssertThrowsError(try lexOne("\"null-byte is not \u{0000} end of file\""))
        // "Syntax Error GraphQL (1:19) Invalid character within String: "\\u0000"."

        XCTAssertThrowsError(try lexOne("\"multi\nline\""))
        // "Syntax Error GraphQL (1:7) Unterminated string"

        XCTAssertThrowsError(try lexOne("\"multi\rline\""))
        // "Syntax Error GraphQL (1:7) Unterminated string"

        XCTAssertThrowsError(try lexOne("\"bad \\z esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\z."

        XCTAssertThrowsError(try lexOne("\"bad \\x esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\x."

        XCTAssertThrowsError(try lexOne("\"bad \\u1 esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\u1 es."

        XCTAssertThrowsError(try lexOne("\"bad \\u0XX1 esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\u0XX1."

        XCTAssertThrowsError(try lexOne("\"bad \\uXXXX esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uXXXX."

        XCTAssertThrowsError(try lexOne("\"bad \\uFXXX esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uFXXX."

        XCTAssertThrowsError(try lexOne("\"bad \\uXXXF esc\""))
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uXXXF."
    }

    func testNumbers() throws {
        var token: Token
        var expected: Token

        token = try lexOne("7")

        expected = Token(
            kind: .int,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "7"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("4.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "4.123"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-4")

        expected = Token(
            kind: .int,
            start: 0,
            end: 2,
            line: 1,
            column: 1,
            value: "-4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("9")

        expected = Token(
            kind: .int,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "9"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("0")

        expected = Token(
            kind: .int,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "0"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-4.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "-4.123"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("0.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "0.123"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("123e4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "123e4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("123E4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "123E4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("123e-4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "123e-4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("123e+4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "123e+4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-1.123e4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 8,
            line: 1,
            column: 1,
            value: "-1.123e4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-1.123E4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 8,
            line: 1,
            column: 1,
            value: "-1.123E4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-1.123e-4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 9,
            line: 1,
            column: 1,
            value: "-1.123e-4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-1.123e+4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 9,
            line: 1,
            column: 1,
            value: "-1.123e+4"
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("-1.123e4567")

        expected = Token(
            kind: .float,
            start: 0,
            end: 11,
            line: 1,
            column: 1,
            value: "-1.123e4567"
        )

        XCTAssertEqual(token, expected)
    }

    func testNumberErrors() throws {
        XCTAssertThrowsError(try lexOne("00"))
//        'Syntax Error GraphQL (1:2) Invalid number, ' +
//        'unexpected digit after 0: "0".'

        XCTAssertThrowsError(try lexOne("+1"))
        // "Syntax Error GraphQL (1:1) Unexpected character "+""

        XCTAssertThrowsError(try lexOne("1."))
//        'Syntax Error GraphQL (1:3) Invalid number, ' +
//        'expected digit but got: <EOF>.'

        XCTAssertThrowsError(try lexOne(".123"))
        // "Syntax Error GraphQL (1:1) Unexpected character ".""

        XCTAssertThrowsError(try lexOne("1.A"))
//        'Syntax Error GraphQL (1:3) Invalid number, ' +
//        'expected digit but got: "A".'

        XCTAssertThrowsError(try lexOne("-A"))
//        'Syntax Error GraphQL (1:2) Invalid number, ' +
//        'expected digit but got: "A".'

        XCTAssertThrowsError(try lexOne("1.0e"))
//        'Syntax Error GraphQL (1:5) Invalid number, ' +
//        'expected digit but got: <EOF>.');

        XCTAssertThrowsError(try lexOne("1.0eA"))
//        'Syntax Error GraphQL (1:5) Invalid number, ' +
//        'expected digit but got: "A".'
    }

    func testSymbols() throws {
        var token: Token
        var expected: Token

        token = try lexOne("!")

        expected = Token(
            kind: .bang,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("$")

        expected = Token(
            kind: .dollar,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("(")

        expected = Token(
            kind: .openingParenthesis,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne(")")

        expected = Token(
            kind: .closingParenthesis,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("...")

        expected = Token(
            kind: .spread,
            start: 0,
            end: 3,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne(":")

        expected = Token(
            kind: .colon,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("=")

        expected = Token(
            kind: .equals,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("@")

        expected = Token(
            kind: .at,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("[")

        expected = Token(
            kind: .openingBracket,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("]")

        expected = Token(
            kind: .closingBracket,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("{")

        expected = Token(
            kind: .openingBrace,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("|")

        expected = Token(
            kind: .pipe,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)

        token = try lexOne("}")

        expected = Token(
            kind: .closingBrace,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        XCTAssertEqual(token, expected)
    }

    func testUnknownCharacterErrors() throws {
        XCTAssertThrowsError(try lexOne(".."))
        // "Syntax Error GraphQL (1:1) Unexpected character ".""

        XCTAssertThrowsError(try lexOne("?"))
        // "Syntax Error GraphQL (1:1) Unexpected character "?""

        XCTAssertThrowsError(try lexOne("\u{203B}"))
        // "Syntax Error GraphQL (1:1) Unexpected character "\\u203B""

        XCTAssertThrowsError(try lexOne("\u{200b}"))
        // "Syntax Error GraphQL (1:1) Unexpected character "\\u200B""
    }

    func testDashInName() throws {
        let q = "a-b"
        let lexer = createLexer(source: Source(body: q))
        let firstToken = try lexer.advance()

        let expected = Token(
            kind: .name,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "a"
        )

        XCTAssertEqual(firstToken, expected)

        XCTAssertThrowsError(try lexer.advance())
        // "Syntax Error GraphQL (1:3) Invalid number, expected digit but got: "b"."
    }

    func testDoubleLinkedList() throws {
        let q = "{\n    #comment\n    field\n    }"
        let lexer = createLexer(source: Source(body: q))

        let startToken = lexer.token
        var endToken: Token

        repeat {
            endToken = try lexer.advance()
            XCTAssertNotEqual(endToken.kind, .comment)
        } while endToken.kind != .eof

        XCTAssertEqual(startToken.prev, nil)
        XCTAssertEqual(endToken.next, nil)

        var tokens: [Token] = []
        var token: Token = startToken

        while true {
            if !tokens.isEmpty {
                XCTAssertEqual(token.prev, tokens[tokens.count - 1])
            }
            tokens.append(token)

            guard let t = token.next else {
                break
            }

            token = t
        }

        let expectedKinds: [Token.Kind] = [
            .sof,
            .openingBrace,
            .comment,
            .name,
            .closingBrace,
            .eof
        ]

        XCTAssertEqual(tokens.map({ $0.kind }), expectedKinds)
    }
}

extension LexerTests {
    static var allTests: [(String, (LexerTests) -> () throws -> Void)] {
        return [
            ("testInvalidCharacter", testInvalidCharacter),
            ("testBOMHeader", testBOMHeader),
            ("testRecordsLineAndColumn", testRecordsLineAndColumn),
            ("testTokenDescription", testTokenDescription),
            ("testSkipsWhitespace", testSkipsWhitespace),
            ("testSkipsComments", testSkipsComments),
            ("testSkipsCommas", testSkipsCommas),
            ("testErrorsRespectWhitespaces", testErrorsRespectWhitespaces),
            ("testStrings", testStrings),
            ("testStringErrors", testStringErrors),
            ("testNumbers", testNumbers),
            ("testNumberErrors", testNumberErrors),
            ("testSymbols", testSymbols),
            ("testUnknownCharacterErrors", testUnknownCharacterErrors),
            ("testDashInName", testDashInName),
            ("testDoubleLinkedList", testDoubleLinkedList),
        ]
    }
}
