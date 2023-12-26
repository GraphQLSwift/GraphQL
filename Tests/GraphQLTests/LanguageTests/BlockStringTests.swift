@testable import GraphQL
import XCTest

class PrintBlockStringTests: XCTestCase {
    func testDoesNotEscapeCharacters() {
        let str = "\" \\ / \n \r \t"
        XCTAssertEqual(printBlockString(str), "\"\"\"\n" + str + "\n\"\"\"")
        XCTAssertEqual(printBlockString(str, minimize: true), "\"\"\"\n" + str + "\"\"\"")
    }

    func testByDefaultPrintBlockStringsAsSingleLine() {
        XCTAssertEqual(printBlockString("one liner"), "\"\"\"one liner\"\"\"")
    }

    func testByDefaultPrintBlockStringsEndingWithTripleQuotationAsMultiLine() {
        let str = "triple quotation \"\"\""
        XCTAssertEqual(printBlockString(str), "\"\"\"\ntriple quotation \\\"\"\"\n\"\"\"")
        XCTAssertEqual(
            printBlockString(str, minimize: true),
            "\"\"\"triple quotation \\\"\"\"\"\"\""
        )
    }

    func testCorrectlyPrintsSingleLineWithLeadingSpace() {
        XCTAssertEqual(
            printBlockString("    space-led value \"quoted string\""),
            "\"\"\"    space-led value \"quoted string\"\n\"\"\""
        )
    }

    func testCorrectlyPrintsSingleLineWithTrailingBackslash() {
        let str = "backslash \\"
        XCTAssertEqual(printBlockString(str), "\"\"\"\nbackslash \\\n\"\"\"")
        XCTAssertEqual(printBlockString(str, minimize: true), "\"\"\"backslash \\\n\"\"\"")
    }

    func testCorrectlyPrintsMultiLineWithInternalIndent() {
        let str = "no indent\n with indent"
        XCTAssertEqual(printBlockString(str), "\"\"\"\nno indent\n with indent\n\"\"\"")
        XCTAssertEqual(
            printBlockString(str, minimize: true),
            "\"\"\"\nno indent\n with indent\"\"\""
        )
    }

    func testCorrectlyPrintsStringWithAFirstLineIndentation() {
        let str = [
            "    first  ",
            "  line     ",
            "indentation",
            "     string",
        ].joined(separator: "\n")

        XCTAssertEqual(
            printBlockString(str),
            [
                "\"\"\"",
                "    first  ",
                "  line     ",
                "indentation",
                "     string",
                "\"\"\"",
            ].joined(separator: "\n")
        )
        XCTAssertEqual(
            printBlockString(str, minimize: true),
            [
                "\"\"\"    first  ",
                "  line     ",
                "indentation",
                "     string\"\"\"",
            ].joined(separator: "\n")
        )
    }
}
