@testable import GraphQL
import Testing

class UniqueFragmentNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueFragmentNamesRule
    }

    @Test func testNoFragments() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    @Test func testOneFragment() throws {
        try assertValid(
            """
            {
              ...fragA
            }

            fragment fragA on Type {
              field
            }
            """
        )
    }

    @Test func testManyFragments() throws {
        try assertValid(
            """
            {
              ...fragA
              ...fragB
              ...fragC
            }
            fragment fragA on Type {
              fieldA
            }
            fragment fragB on Type {
              fieldB
            }
            fragment fragC on Type {
              fieldC
            }
            """
        )
    }

    @Test func testInlineFragmentsAreAlwaysUnique() throws {
        try assertValid(
            """
            {
              ...on Type {
                fieldA
              }
              ...on Type {
                fieldB
              }
            }
            """
        )
    }

    @Test func testFragmentAndOperationNamedTheSame() throws {
        try assertValid(
            """
            query Foo {
              ...Foo
            }
            fragment Foo on Type {
              field
            }
            """
        )
    }

    @Test func testFragmentsNamedTheSame() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              ...fragA
            }
            fragment fragA on Type {
              fieldA
            }
            fragment fragA on Type {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 4, column: 10),
                (line: 7, column: 10),
            ],
            message: "There can be only one fragment named \"fragA\"."
        )
    }

    @Test func testFragmentsNamedTheSameWithoutBeingReferenced() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment fragA on Type {
              fieldA
            }
            fragment fragA on Type {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 10),
                (line: 4, column: 10),
            ],
            message: "There can be only one fragment named \"fragA\"."
        )
    }
}
