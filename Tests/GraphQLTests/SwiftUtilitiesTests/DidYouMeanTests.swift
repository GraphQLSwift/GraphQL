@testable import GraphQL
import Testing

@Suite struct DidYouMeanTests {
    @Test func testEmptyList() {
        #expect(
            didYouMean(suggestions: []) == ""
        )
    }

    @Test func testSingleSuggestion() {
        #expect(
            didYouMean(
                suggestions: ["A"]
            ) == #" Did you mean "A"?"#
        )
    }

    @Test func testTwoSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B"]
            ) == #" Did you mean "A" or "B"?"#
        )
    }

    @Test func testMultipleSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B", "C"]
            ) == #" Did you mean "A", "B", or "C"?"#
        )
    }

    @Test func testLimitsToFiveSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B", "C", "D", "E", "F"]
            ) == #" Did you mean "A", "B", "C", "D", or "E"?"#
        )
    }

    @Test func testAddsSubmessage() {
        #expect(
            didYouMean(
                "the letter",
                suggestions: ["A"]
            ) == #" Did you mean the letter "A"?"#
        )
    }
}
