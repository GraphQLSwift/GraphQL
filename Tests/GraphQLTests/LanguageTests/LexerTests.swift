@testable import GraphQL
import Testing

func lexOne(_ string: String) throws -> Token {
    let lexer = createLexer(source: Source(body: string))
    return try lexer.advance()
}

@Suite struct LexerTests {
    @Test func invalidCharacter() throws {
        #expect(throws: (any Error).self) { try lexOne("\u{0007}") }
//        'Syntax Error GraphQL (1:1) Invalid character "\\u0007"'
    }

    @Test func bOMHeader() throws {
        let token = try lexOne("\u{FEFF} foo")

        let expected = Token(
            kind: .name,
            start: 4,
            end: 7,
            line: 1,
            column: 5, // TODO: Ignore BOM when counting characters making this 2.
            value: "foo"
        )

        #expect(token == expected)
    }

    @Test func recordsLineAndColumn() throws {
        let token = try lexOne("\n \r\n \r  foo\n")

        let expected = Token(
            kind: .name,
            start: 8,
            end: 11,
            line: 4,
            column: 3,
            value: "foo"
        )

        #expect(token == expected)
    }

    @Test func tokenDescription() throws {
        let token = try lexOne("foo")
        let expected = "Token(kind: Name, value: foo, line: 1, column: 1)"
        #expect(token.description == expected)
    }

    @Test func skipsWhitespace() throws {
        let token = try lexOne("""


            foo


        """)

        let expected = Token(
            kind: .name,
            start: 6,
            end: 9,
            line: 3,
            column: 5,
            value: "foo"
        )

        #expect(token == expected)
    }

    @Test func skipsComments() throws {
        let token = try lexOne("""
            #comment\r
            foo#comment
        """)

        let expected = Token(
            kind: .name,
            start: 18,
            end: 21,
            line: 2,
            column: 5,
            value: "foo"
        )

        #expect(token == expected)
    }

    @Test func skipsCommas() throws {
        let token = try lexOne(",,,foo,,,")

        let expected = Token(
            kind: .name,
            start: 3,
            end: 6,
            line: 1,
            column: 4,
            value: "foo"
        )

        #expect(token == expected)
    }

    @Test func errorsRespectWhitespaces() throws {
        #expect(throws: (any Error).self) { try lexOne("""


        ?


        """) }
//      'Syntax Error GraphQL (3:5) Unexpected character "?".\n' +
//      '\n' +
//      '2: \n' +
//      '3:     ?\n' +
//      '       ^\n' +
//      '4: \n'
    }

    @Test func strings() throws {
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

        #expect(token == expected)

        token = try lexOne("\"😎\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "😎"
        )

        #expect(token == expected)

        token = try lexOne("\" white space \"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 15,
            line: 1,
            column: 1,
            value: " white space "
        )

        #expect(token == expected)

        token = try lexOne("\"quote \\\"\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 10,
            line: 1,
            column: 1,
            value: "quote \""
        )

        #expect(token == expected)

        token = try lexOne("\"escaped \\n\\r\\b\\t\\f\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 20,
            line: 1,
            column: 1,
            value: "escaped \n\r\u{8}\u{9}\u{12}"
        )

        #expect(token == expected)

        token = try lexOne("\"slashes \\\\\\\\ \\\\/\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 18,
            line: 1,
            column: 1,
            value: "slashes \\\\ \\/"
        )

        #expect(token == expected)

        token = try lexOne("\"unicode \\u1234\\u5678\\u90AB\\uCDEF\"")

        expected = Token(
            kind: .string,
            start: 0,
            end: 34,
            line: 1,
            column: 1,
            value: "unicode \u{1234}\u{5678}\u{90AB}\u{CDEF}"
        )

        #expect(token == expected)
    }

    @Test func stringErrors() throws {
        #expect(throws: (any Error).self) { try lexOne("\"") }
        // "Syntax Error GraphQL (1:2) Unterminated string"

        #expect(throws: (any Error).self) {
            try lexOne("\"contains unescaped \u{0007} control char\"")
        }
        // "Syntax Error GraphQL (1:21) Invalid character within String: "\\u0007"."

        #expect(throws: (any Error).self) {
            try lexOne("\"null-byte is not \u{0000} end of file\"")
        }
        // "Syntax Error GraphQL (1:19) Invalid character within String: "\\u0000"."

        #expect(throws: (any Error).self) {
            try lexOne("""
            "multi
            line"
            """)
        }
        // "Syntax Error GraphQL (1:7) Unterminated string"

        #expect(throws: (any Error).self) { try lexOne("\"multi\rline\"") }
        // "Syntax Error GraphQL (1:7) Unterminated string"

        #expect(throws: (any Error).self) { try lexOne("\"bad \\z esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\z."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\x esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\x."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\u1 esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\u1 es."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\u0XX1 esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\u0XX1."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\uXXXX esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uXXXX."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\uFXXX esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uFXXX."

        #expect(throws: (any Error).self) { try lexOne("\"bad \\uXXXF esc\"") }
        // "Syntax Error GraphQL (1:7) Invalid character escape sequence: \\uXXXF."
    }

    @Test func numbers() throws {
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

        #expect(token == expected)

        token = try lexOne("4.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "4.123"
        )

        #expect(token == expected)

        token = try lexOne("-4")

        expected = Token(
            kind: .int,
            start: 0,
            end: 2,
            line: 1,
            column: 1,
            value: "-4"
        )

        #expect(token == expected)

        token = try lexOne("9")

        expected = Token(
            kind: .int,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "9"
        )

        #expect(token == expected)

        token = try lexOne("0")

        expected = Token(
            kind: .int,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: "0"
        )

        #expect(token == expected)

        token = try lexOne("-4.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "-4.123"
        )

        #expect(token == expected)

        token = try lexOne("0.123")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "0.123"
        )

        #expect(token == expected)

        token = try lexOne("123e4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "123e4"
        )

        #expect(token == expected)

        token = try lexOne("123E4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 5,
            line: 1,
            column: 1,
            value: "123E4"
        )

        #expect(token == expected)

        token = try lexOne("123e-4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "123e-4"
        )

        #expect(token == expected)

        token = try lexOne("123e+4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 6,
            line: 1,
            column: 1,
            value: "123e+4"
        )

        #expect(token == expected)

        token = try lexOne("-1.123e4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 8,
            line: 1,
            column: 1,
            value: "-1.123e4"
        )

        #expect(token == expected)

        token = try lexOne("-1.123E4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 8,
            line: 1,
            column: 1,
            value: "-1.123E4"
        )

        #expect(token == expected)

        token = try lexOne("-1.123e-4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 9,
            line: 1,
            column: 1,
            value: "-1.123e-4"
        )

        #expect(token == expected)

        token = try lexOne("-1.123e+4")

        expected = Token(
            kind: .float,
            start: 0,
            end: 9,
            line: 1,
            column: 1,
            value: "-1.123e+4"
        )

        #expect(token == expected)

        token = try lexOne("-1.123e4567")

        expected = Token(
            kind: .float,
            start: 0,
            end: 11,
            line: 1,
            column: 1,
            value: "-1.123e4567"
        )

        #expect(token == expected)
    }

    @Test func numberErrors() throws {
        #expect(throws: (any Error).self) { try lexOne("00") }
//        'Syntax Error GraphQL (1:2) Invalid number, ' +
//        'unexpected digit after 0: "0".'

        #expect(throws: (any Error).self) { try lexOne("+1") }
        // "Syntax Error GraphQL (1:1) Unexpected character "+""

        #expect(throws: (any Error).self) { try lexOne("1.") }
//        'Syntax Error GraphQL (1:3) Invalid number, ' +
//        'expected digit but got: <EOF>.'

        #expect(throws: (any Error).self) { try lexOne(".123") }
        // "Syntax Error GraphQL (1:1) Unexpected character ".""

        #expect(throws: (any Error).self) { try lexOne("1.A") }
//        'Syntax Error GraphQL (1:3) Invalid number, ' +
//        'expected digit but got: "A".'

        #expect(throws: (any Error).self) { try lexOne("-A") }
//        'Syntax Error GraphQL (1:2) Invalid number, ' +
//        'expected digit but got: "A".'

        #expect(throws: (any Error).self) { try lexOne("1.0e") }
//        'Syntax Error GraphQL (1:5) Invalid number, ' +
//        'expected digit but got: <EOF>.');

        #expect(throws: (any Error).self) { try lexOne("1.0eA") }
//        'Syntax Error GraphQL (1:5) Invalid number, ' +
//        'expected digit but got: "A".'
    }

    @Test func symbols() throws {
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

        #expect(token == expected)

        token = try lexOne("$")

        expected = Token(
            kind: .dollar,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("(")

        expected = Token(
            kind: .openingParenthesis,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne(")")

        expected = Token(
            kind: .closingParenthesis,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("...")

        expected = Token(
            kind: .spread,
            start: 0,
            end: 3,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne(":")

        expected = Token(
            kind: .colon,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("=")

        expected = Token(
            kind: .equals,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("@")

        expected = Token(
            kind: .at,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("[")

        expected = Token(
            kind: .openingBracket,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("]")

        expected = Token(
            kind: .closingBracket,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("{")

        expected = Token(
            kind: .openingBrace,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("|")

        expected = Token(
            kind: .pipe,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)

        token = try lexOne("}")

        expected = Token(
            kind: .closingBrace,
            start: 0,
            end: 1,
            line: 1,
            column: 1,
            value: nil
        )

        #expect(token == expected)
    }

    @Test func unknownCharacterErrors() throws {
        #expect(throws: (any Error).self) { try lexOne("..") }
        // "Syntax Error GraphQL (1:1) Unexpected character ".""

        #expect(throws: (any Error).self) { try lexOne("?") }
        // "Syntax Error GraphQL (1:1) Unexpected character "?""

        #expect(throws: (any Error).self) { try lexOne("\u{203B}") }
        // "Syntax Error GraphQL (1:1) Unexpected character "\\u203B""

        #expect(throws: (any Error).self) { try lexOne("\u{200b}") }
        // "Syntax Error GraphQL (1:1) Unexpected character "\\u200B""
    }

    @Test func dashInName() throws {
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

        #expect(firstToken == expected)

        #expect(throws: (any Error).self) { try lexer.advance() }
        // "Syntax Error GraphQL (1:3) Invalid number, expected digit but got: "b"."
    }

    @Test func doubleLinkedList() throws {
        let q = """
        {
            #comment
            field
        }
        """
        let lexer = createLexer(source: Source(body: q))

        let startToken = lexer.token
        var endToken: Token

        repeat {
            endToken = try lexer.advance()
            #expect(endToken.kind != .comment)
        } while
            endToken.kind != .eof

        #expect(startToken.prev == nil)
        #expect(endToken.next == nil)

        var tokens: [Token] = []
        var token: Token = startToken

        while true {
            if !tokens.isEmpty {
                #expect(token.prev == tokens[tokens.count - 1])
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
            .eof,
        ]

        #expect(tokens.map { $0.kind } == expectedKinds)
    }

    //
    // Tests for Blockstring support
    //

    @Test func blockStringIndentAndBlankLine() throws {
        let rawString =
            """



                TopLevel {
                    indented
                    alsoIndented
                }


            \t\t

            """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(cleanedString == """
        TopLevel {
            indented
            alsoIndented
        }
        """)
    }

    @Test func blockStringDoubleIndentAndBlankLine() throws {
        let rawString =
            """



                TopLevel {
                    indented: {
                        foo: String
                    }
                    alsoIndented
                }


            \t\t

            """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(
            cleanedString == """
            TopLevel {
                indented: {
                    foo: String
                }
                alsoIndented
            }
            """
        )
    }

    @Test func blockStringIndentAndBlankLineFirstLineNotIndent() throws {
        let rawString = """



        TopLevel {
                indented
                alsoIndented
        }


        \t\t

        """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(cleanedString == """
        TopLevel {
                indented
                alsoIndented
        }
        """)
    }

    @Test func blockStringIndentBlankLineFirstLineNotIndentWeird() throws {
        let rawString = """


        TopLevel {
            indented
            alsoIndented
        }


        \t
        """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(cleanedString == """
        TopLevel {
            indented
            alsoIndented
        }
        """)
    }

    @Test func blockStringIndentMultilineWithSingleSpaceIndent() throws {
        let rawString = """
         Multi-line string
         With Inner \"foo\"
         should be Valid
        """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(cleanedString == """
         Multi-line string
        With Inner \"foo\"
        should be Valid
        """)
    }

    @Test func blockStringIndentMultilineWithSingleSpaceIndentExtraLines() throws {
        let rawString = """

         Multi-line string
         With Inner \"foo\"
         should be Valid
        """
        let cleanedString = blockStringValue(rawValue: rawString)

        #expect(cleanedString == """
        Multi-line string
        With Inner \"foo\"
        should be Valid
        """)
    }

    // Lexer tests for Blockstring token parsing

    @Test func blockStrings() throws {
        let token = try lexOne(#" """ Multi-line string\n With Inner "foo" \nshould be Valid """ "#)
        let expected = Token(
            kind: .blockstring,
            start: 1,
            end: 63,
            line: 1,
            column: 2,
            value: " Multi-line string\\n With Inner \"foo\" \\nshould be Valid "
        )

        #expect(
            token == expected,
            """

            expected:
            \(dump(expected))

            got:
            \(dump(token))

            """
        )
    }

    @Test func blockStringSingleSpaceIndent() throws {
        let token = try lexOne(#"""
        """
         Multi-line string
         With Inner "foo"
         should be Valid
        """
        """#)
        let expected = Token(
            kind: .blockstring,
            start: 0,
            end: 61,
            line: 1,
            column: 1,
            value: """
            Multi-line string
            With Inner \"foo\"
            should be Valid
            """
        )

        #expect(
            token == expected,
            """

            expected:
             \(dump(expected))

            got:
            \(dump(token))

            """
        )
    }

    @Test func blockStringUnescapedReturns() throws {
        let token = try lexOne(#"""
        """
         Multi-line string
        with Inner "foo"
        should be valid
        """
        """#)

        let expected = Token(
            kind: .blockstring,
            start: 0,
            end: 59,
            line: 1,
            column: 1,
            value: """
             Multi-line string
            with Inner "foo"
            should be valid
            """
        )

        #expect(token == expected)
    }

    @Test func blockStringUnescapedReturnsIndentTest() throws {
        let token = try lexOne(#"""
        """
        Multi-line string {
            with Inner "foo"
            should be valid indented
        }
        """
        """#)

        let expected = Token(
            kind: .blockstring,
            start: 0,
            end: 79,
            line: 1,
            column: 1,
            value: """
            Multi-line string {
                with Inner \"foo\"
                should be valid indented
            }
            """
        )

        #expect(token == expected)
    }

    @Test func indentedBlockStringWithIndents() throws {
        let sourceStr =
            #"""
                """
                Multi-line string {
                    with Inner "foo"
                    should be valid indented
                }
                """
            """#

        let token = try lexOne(sourceStr)

        let expected = Token(
            kind: .blockstring,
            start: 4,
            end: 103,
            line: 1,
            column: 5,
            value: """
            Multi-line string {
                with Inner \"foo\"
                should be valid indented
            }
            """
        )

        print(sourceStr)

        #expect(token == expected)
    }

    // Test empty strings & multi-line string lexer token parsing

    @Test func emptyQuote() throws {
        let token = try lexOne(#" "" "#)
        let expected = Token(kind: .string, start: 1, end: 3, line: 1, column: 2, value: "")
        #expect(token == expected)
    }

    @Test func emptySimpleBlockString() throws {
        let token = try lexOne(#" """""" "#)
        let expected = Token(kind: .blockstring, start: 1, end: 7, line: 1, column: 2, value: "")
        #expect(token == expected)
    }

    @Test func emptyTrimmedCharactersBlockString() throws {
        let token = try lexOne(#"""
        """
        """
        """#)
        let expected = Token(kind: .blockstring, start: 0, end: 7, line: 1, column: 1, value: "")
        #expect(token == expected)
    }

    @Test func escapedTripleQuoteInBlockString() throws {
        let token = try lexOne(#"""
        """
        \"""
        """
        """#)
        let expected = Token(
            kind: .blockstring,
            start: 0,
            end: 12,
            line: 1,
            column: 1,
            value: "\"\"\""
        )
        #expect(token == expected)
    }
}
