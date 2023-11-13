@testable import GraphQL
import XCTest

class UniqueFragmentNamesRuleTests: ValidationTestCase {
    override func setUp() {
        rule = UniqueFragmentNamesRule
    }

    func testNoFragments() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    func testOneFragment() throws {
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

    func testManyFragments() throws {
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

    func testInlineFragmentsAreAlwaysUnique() throws {
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

    func testFragmentAndOperationNamedTheSame() throws {
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

    func testFragmentsNamedTheSame() throws {
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

    func testFragmentsNamedTheSameWithoutBeingReferenced() throws {
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
