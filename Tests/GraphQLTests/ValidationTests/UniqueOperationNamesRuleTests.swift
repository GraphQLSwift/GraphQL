@testable import GraphQL
import Testing

class UniqueOperationNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueOperationNamesRule
    }

    @Test func noOperations() throws {
        try assertValid(
            """
            fragment fragA on Type {
              field
            }
            """
        )
    }

    @Test func oneAnonOperation() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    @Test func oneNamedOperation() throws {
        try assertValid(
            """
            query Foo {
              field
            }
            """
        )
    }

    @Test func multipleOperations() throws {
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

    @Test func multipleOperationsOfDifferentTypes() throws {
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

    @Test func fragmentAndOperationNamedTheSame() throws {
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

    @Test func multipleOperationsOfSameName() throws {
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

    @Test func multipleOperationsOfDifferentTypesMutation() throws {
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

    @Test func multipleOperationsOfDifferentTypesSubscription() throws {
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
