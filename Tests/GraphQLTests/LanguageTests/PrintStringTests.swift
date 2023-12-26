@testable import GraphQL
import XCTest

class PrintStringTests: XCTestCase {
    func testPrintsASimpleString() {
        XCTAssertEqual(printString("hello world"), "\"hello world\"")
    }

    func testEscapesQutoes() {
        XCTAssertEqual(printString("\"hello world\""), "\"\\\"hello world\\\"\"")
    }

    func testDoesNotEscapeSingleQuote() {
        XCTAssertEqual(printString("who's test"), "\"who's test\"")
    }

    func testEscapesBackslashes() {
        XCTAssertEqual(printString("escape: \\"), "\"escape: \\\\\"")
    }

    func testEscapesWellKnownControlChars() {
        XCTAssertEqual(printString("\n\r\t"), "\"\\n\\r\\t\"")
    }

    func testEscapesZeroByte() {
        XCTAssertEqual(printString("\u{0000}"), "\"\\u0000\"")
    }

    func testDoesNotEscapeSpace() {
        XCTAssertEqual(printString(" "), "\" \"")
    }

    // TODO: We only support UTF8
    func testDoesNotEscapeSupplementaryCharacter() {
        XCTAssertEqual(printString("\u{1f600}"), "\"\u{1f600}\"")
    }

    func testEscapesAllControlChars() {
        XCTAssertEqual(
            printString(
                "\u{0000}\u{0001}\u{0002}\u{0003}\u{0004}\u{0005}\u{0006}\u{0007}" +
                    "\u{0008}\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{000E}\u{000F}" +
                    "\u{0010}\u{0011}\u{0012}\u{0013}\u{0014}\u{0015}\u{0016}\u{0017}" +
                    "\u{0018}\u{0019}\u{001A}\u{001B}\u{001C}\u{001D}\u{001E}\u{001F}" +
                    "\u{0020}\u{0021}\u{0022}\u{0023}\u{0024}\u{0025}\u{0026}\u{0027}" +
                    "\u{0028}\u{0029}\u{002A}\u{002B}\u{002C}\u{002D}\u{002E}\u{002F}" +
                    "\u{0030}\u{0031}\u{0032}\u{0033}\u{0034}\u{0035}\u{0036}\u{0037}" +
                    "\u{0038}\u{0039}\u{003A}\u{003B}\u{003C}\u{003D}\u{003E}\u{003F}" +
                    "\u{0040}\u{0041}\u{0042}\u{0043}\u{0044}\u{0045}\u{0046}\u{0047}" +
                    "\u{0048}\u{0049}\u{004A}\u{004B}\u{004C}\u{004D}\u{004E}\u{004F}" +
                    "\u{0050}\u{0051}\u{0052}\u{0053}\u{0054}\u{0055}\u{0056}\u{0057}" +
                    "\u{0058}\u{0059}\u{005A}\u{005B}\u{005C}\u{005D}\u{005E}\u{005F}" +
                    "\u{0060}\u{0061}\u{0062}\u{0063}\u{0064}\u{0065}\u{0066}\u{0067}" +
                    "\u{0068}\u{0069}\u{006A}\u{006B}\u{006C}\u{006D}\u{006E}\u{006F}" +
                    "\u{0070}\u{0071}\u{0072}\u{0073}\u{0074}\u{0075}\u{0076}\u{0077}" +
                    "\u{0078}\u{0079}\u{007A}\u{007B}\u{007C}\u{007D}\u{007E}\u{007F}" +
                    "\u{0080}\u{0081}\u{0082}\u{0083}\u{0084}\u{0085}\u{0086}\u{0087}" +
                    "\u{0088}\u{0089}\u{008A}\u{008B}\u{008C}\u{008D}\u{008E}\u{008F}" +
                    "\u{0090}\u{0091}\u{0092}\u{0093}\u{0094}\u{0095}\u{0096}\u{0097}" +
                    "\u{0098}\u{0099}\u{009A}\u{009B}\u{009C}\u{009D}\u{009E}\u{009F}"
            ),
            "\"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007" +
                "\\b\\t\\n\\u000B\\f\\r\\u000E\\u000F" +
                "\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017" +
                "\\u0018\\u0019\\u001A\\u001B\\u001C\\u001D\\u001E\\u001F" +
                " !\\\"#$%&\'()*+,-./0123456789:;<=>?" +
                "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\\\]^_" +
                "`abcdefghijklmnopqrstuvwxyz{|}~\\u007F" +
                "\\u0080\\u0081\\u0082\\u0083\\u0084\\u0085\\u0086\\u0087" +
                "\\u0088\\u0089\\u008A\\u008B\\u008C\\u008D\\u008E\\u008F" +
                "\\u0090\\u0091\\u0092\\u0093\\u0094\\u0095\\u0096\\u0097" +
                "\\u0098\\u0099\\u009A\\u009B\\u009C\\u009D\\u009E\\u009F\""
        )
    }
}
