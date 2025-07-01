@testable import GraphQL
import Testing

@Suite struct PrintBlockStringTests {
    @Test func testDoesNotEscapeCharacters() {
        let str = "\" \\ / \n \r \t"
        #expect(printBlockString(str) == "\"\"\"\n" + str + "\n\"\"\"")
        #expect(printBlockString(str, minimize: true) == "\"\"\"\n" + str + "\"\"\"")
    }

    @Test func testByDefaultPrintBlockStringsAsSingleLine() {
        #expect(printBlockString("one liner") == "\"\"\"one liner\"\"\"")
    }

    @Test func testByDefaultPrintBlockStringsEndingWithTripleQuotationAsMultiLine() {
        let str = "triple quotation \"\"\""
        #expect(printBlockString(str) == "\"\"\"\ntriple quotation \\\"\"\"\n\"\"\"")
        #expect(
            printBlockString(str, minimize: true) ==
                "\"\"\"triple quotation \\\"\"\"\"\"\""
        )
    }

    @Test func testCorrectlyPrintsSingleLineWithLeadingSpace() {
        #expect(
            printBlockString("    space-led value \"quoted string\"") ==
                "\"\"\"    space-led value \"quoted string\"\n\"\"\""
        )
    }

    @Test func testCorrectlyPrintsSingleLineWithTrailingBackslash() {
        let str = "backslash \\"
        #expect(printBlockString(str) == "\"\"\"\nbackslash \\\n\"\"\"")
        #expect(printBlockString(str, minimize: true) == "\"\"\"backslash \\\n\"\"\"")
    }

    @Test func testCorrectlyPrintsMultiLineWithInternalIndent() {
        let str = "no indent\n with indent"
        #expect(printBlockString(str) == "\"\"\"\nno indent\n with indent\n\"\"\"")
        #expect(
            printBlockString(str, minimize: true) ==
                "\"\"\"\nno indent\n with indent\"\"\""
        )
    }

    @Test func testCorrectlyPrintsStringWithAFirstLineIndentation() {
        let str = [
            "    first  ",
            "  line     ",
            "indentation",
            "     string",
        ].joined(separator: "\n")

        #expect(
            printBlockString(str) == [
                "\"\"\"",
                "    first  ",
                "  line     ",
                "indentation",
                "     string",
                "\"\"\"",
            ].joined(separator: "\n")
        )
        #expect(
            printBlockString(str, minimize: true) == [
                "\"\"\"    first  ",
                "  line     ",
                "indentation",
                "     string\"\"\"",
            ].joined(separator: "\n")
        )
    }
}
