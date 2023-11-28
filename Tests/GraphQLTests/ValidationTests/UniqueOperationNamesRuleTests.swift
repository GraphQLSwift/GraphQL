@testable import GraphQL
import XCTest

class UniqueOperationNamesRuleTests: ValidationTestCase {
    override func setUp() {
        rule = UniqueOperationNamesRule
    }

    func testNoOperations() throws {
        try assertValid(
            """
            fragment fragA on Type {
              field
            }
            """
        )
    }

    func testOneAnonOperation() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    func testOneNamedOperation() throws {
        try assertValid(
            """
            query Foo {
              field
            }
            """
        )
    }

    func testMultipleOperations() throws {
        try assertValid(
            """
            query Foo {
              field
            }

            query Bar {
              field
            }
            """
        )
    }

    func testMultipleOperationsOfDifferentTypes() throws {
        try assertValid(
            """
            query Foo {
              field
            }

            mutation Bar {
              field
            }

            subscription Baz {
              field
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

    func testMultipleOperationsOfSameName() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Foo {
              fieldA
            }
            query Foo {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 7),
                (line: 4, column: 7),
            ],
            message: "There can be only one operation named \"Foo\"."
        )
    }

    func testMultipleOperationsOfDifferentTypesMutation() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Foo {
              fieldA
            }
            mutation Foo {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 7),
                (line: 4, column: 10),
            ],
            message: "There can be only one operation named \"Foo\"."
        )
    }

    func testMultipleOperationsOfDifferentTypesSubscription() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Foo {
              fieldA
            }
            subscription Foo {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 7),
                (line: 4, column: 14),
            ],
            message: "There can be only one operation named \"Foo\"."
        )
    }
}
