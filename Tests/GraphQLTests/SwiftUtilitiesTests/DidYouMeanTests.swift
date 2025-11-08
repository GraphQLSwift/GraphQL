@testable import GraphQL
import Testing

@Suite struct DidYouMeanTests {
    @Test func emptyList() {
        #expect(
            didYouMean(suggestions: []) == ""
        )
    }

    @Test func singleSuggestion() {
        #expect(
            didYouMean(
                suggestions: ["A"]
            ) == #" Did you mean "A"?"#
        )
    }

    @Test func twoSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B"]
            ) == #" Did you mean "A" or "B"?"#
        )
    }

    @Test func multipleSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B", "C"]
            ) == #" Did you mean "A", "B", or "C"?"#
        )
    }

    @Test func limitsToFiveSuggestions() {
        #expect(
            didYouMean(
                suggestions: ["A", "B", "C", "D", "E", "F"]
            ) == #" Did you mean "A", "B", "C", "D", or "E"?"#
        )
    }

    @Test func addsSubmessage() {
        #expect(
            didYouMean(
                "the letter",
                suggestions: ["A"]
            ) == #" Did you mean the letter "A"?"#
        )
    }
}
