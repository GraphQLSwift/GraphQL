@testable import GraphQL
import Testing

class NoFragmentCyclesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = NoFragmentCyclesRule
    }

    @Test func testSingleReferenceIsValid() throws {
        try assertValid(
            """
            fragment fragA on Dog { ...fragB }
            fragment fragB on Dog { name }
            """
        )
    }

    @Test func testSpreadingTwiceIsNotCircular() throws {
        try assertValid(
            """
            fragment fragA on Dog { ...fragB, ...fragB }
            fragment fragB on Dog { name }
            """
        )
    }

    @Test func testSpreadingTwiceIndirectlyIsNotCircular() throws {
        try assertValid(
            """
            fragment fragA on Dog { ...fragB, ...fragC }
            fragment fragB on Dog { ...fragC }
            fragment fragC on Dog { name }
            """
        )
    }

    @Test func testDoubleSpreadWithinAbstractTypes() throws {
        try assertValid(
            """
            fragment nameFragment on Pet {
              ... on Dog { name }
              ... on Cat { name }
            }

            fragment spreadsInAnon on Pet {
              ... on Dog { ...nameFragment }
              ... on Cat { ...nameFragment }
            }
            """
        )
    }

    @Test func testDoesNotFalsePositiveOnUnknownFragment() throws {
        try assertValid(
            """
            fragment nameFragment on Pet {
              ...UnknownFragment
            }
            """
        )
    }

    @Test func testSpreadingRecursivelyWithinFieldFails() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragA on Human { relatives { ...fragA } },
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 39)],
            message: "Cannot spread fragment \"fragA\" within itself."
        )
    }

    @Test func testNoSpreadingItselfDirectly() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragA on Dog { ...fragA }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 25)],
            message: "Cannot spread fragment \"fragA\" within itself."
        )
    }

    @Test func testNoSpreadingItselfDirectlyWithinInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragA on Pet {
              ... on Dog {
                ...fragA
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 5)],
            message: "Cannot spread fragment \"fragA\" within itself."
        )
    }

    @Test func testNoSpreadingItselfIndirectly() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragA on Dog { ...fragB }
            fragment fragB on Dog { ...fragA }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 25),
                (line: 2, column: 25),
            ],
            message: "Cannot spread fragment \"fragA\" within itself via \"fragB\"."
        )
    }

    @Test func testNoSpreadingItselfIndirectlyReportsOppositeOrder() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragB on Dog { ...fragA }
            fragment fragA on Dog { ...fragB }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 25),
                (line: 2, column: 25),
            ],
            message: "Cannot spread fragment \"fragB\" within itself via \"fragA\"."
        )
    }

    @Test func testNoSpreadingItselfIndirectlyWithinInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment fragA on Pet {
              ... on Dog {
                ...fragB
              }
            }
            fragment fragB on Pet {
              ... on Dog {
                ...fragA
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 3, column: 5),
                (line: 8, column: 5),
            ],
            message: "Cannot spread fragment \"fragA\" within itself via \"fragB\"."
        )
    }

    @Test func testNoSpreadingItselfDeeply() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            fragment fragA on Dog { ...fragB }
            fragment fragB on Dog { ...fragC }
            fragment fragC on Dog { ...fragO }
            fragment fragX on Dog { ...fragY }
            fragment fragY on Dog { ...fragZ }
            fragment fragZ on Dog { ...fragO }
            fragment fragO on Dog { ...fragP }
            fragment fragP on Dog { ...fragA, ...fragX }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 25),
                (line: 2, column: 25),
                (line: 3, column: 25),
                (line: 7, column: 25),
                (line: 8, column: 25),
            ],
            message: #"Cannot spread fragment "fragA" within itself via "fragB", "fragC", "fragO", "fragP"."#
        )

        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 7, column: 25),
                (line: 8, column: 35),
                (line: 4, column: 25),
                (line: 5, column: 25),
                (line: 6, column: 25),
            ],
            message: #"Cannot spread fragment "fragO" within itself via "fragP", "fragX", "fragY", "fragZ"."#
        )
    }

    @Test func testNoSpreadingItselfDeeplyTwoPaths() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            fragment fragA on Dog { ...fragB, ...fragC }
            fragment fragB on Dog { ...fragA }
            fragment fragC on Dog { ...fragA }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 25),
                (line: 2, column: 25),
            ],
            message: #"Cannot spread fragment "fragA" within itself via "fragB"."#
        )

        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 1, column: 35),
                (line: 3, column: 25),
            ],
            message: #"Cannot spread fragment "fragA" within itself via "fragC"."#
        )
    }

    @Test func testNoSpreadingItselfDeeplyTwoPathsAltTraverseOrder() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            fragment fragA on Dog { ...fragC }
            fragment fragB on Dog { ...fragC }
            fragment fragC on Dog { ...fragA, ...fragB }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 25),
                (line: 3, column: 25),
            ],
            message: #"Cannot spread fragment "fragA" within itself via "fragC"."#
        )

        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 3, column: 35),
                (line: 2, column: 25),
            ],
            message: #"Cannot spread fragment "fragC" within itself via "fragB"."#
        )
    }

    @Test func testNoSpreadingItselfDeeplyAndImmediately() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query: """
            fragment fragA on Dog { ...fragB }
            fragment fragB on Dog { ...fragB, ...fragC }
            fragment fragC on Dog { ...fragA, ...fragB }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 25),
            ],
            message: #"Cannot spread fragment "fragB" within itself."#
        )

        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 1, column: 25),
                (line: 2, column: 35),
                (line: 3, column: 25),
            ],
            message: #"Cannot spread fragment "fragA" within itself via "fragB", "fragC"."#
        )

        try assertValidationError(
            error: errors[2],
            locations: [
                (line: 2, column: 35),
                (line: 3, column: 35),
            ],
            message: #"Cannot spread fragment "fragB" within itself via "fragC"."#
        )
    }
}
