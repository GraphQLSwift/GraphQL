@testable import GraphQL
import XCTest

class DidYouMeanTests: XCTestCase {
    func testEmptyList() {
        XCTAssertEqual(
            didYouMean(suggestions: []),
            ""
        )
    }

    func testSingleSuggestion() {
        XCTAssertEqual(
            didYouMean(suggestions: ["A"]),
            #" Did you mean "A"?"#
        )
    }

    func testTwoSuggestions() {
        XCTAssertEqual(
            didYouMean(suggestions: ["A", "B"]),
            #" Did you mean "A" or "B"?"#
        )
    }

    func testMultipleSuggestions() {
        XCTAssertEqual(
            didYouMean(suggestions: ["A", "B", "C"]),
            #" Did you mean "A", "B", or "C"?"#
        )
    }

    func testLimitsToFiveSuggestions() {
        XCTAssertEqual(
            didYouMean(suggestions: ["A", "B", "C", "D", "E", "F"]),
            #" Did you mean "A", "B", "C", "D", or "E"?"#
        )
    }

    func testAddsSubmessage() {
        XCTAssertEqual(
            didYouMean("the letter", suggestions: ["A"]),
            #" Did you mean the letter "A"?"#
        )
    }
}
