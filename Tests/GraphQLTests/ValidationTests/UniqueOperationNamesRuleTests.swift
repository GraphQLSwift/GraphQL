@testable import GraphQL
import Testing

class UniqueOperationNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueOperationNamesRule
    }

    @Test func testNoOperations() throws {
        try assertValid(
            """
            fragment fragA on Type {
              field
            }
            """
        )
    }

    @Test func testOneAnonOperation() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    @Test func testOneNamedOperation() throws {
        try assertValid(
            """
            query Foo {
              field
            }
            """
        )
    }

    @Test func testMultipleOperations() throws {
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

    @Test func testMultipleOperationsOfDifferentTypes() throws {
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

    @Test func testMultipleOperationsOfSameName() throws {
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

    @Test func testMultipleOperationsOfDifferentTypesMutation() throws {
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

    @Test func testMultipleOperationsOfDifferentTypesSubscription() throws {
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
