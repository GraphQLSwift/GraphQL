@testable import GraphQL
import Testing

class LoneAnonymousOperationRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = LoneAnonymousOperationRule
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

    @Test func multipleNamedOperations() throws {
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

    @Test func anonOperationWithFragment() throws {
        try assertValid(
            """
            {
              ...Foo
            }
            fragment Foo on Type {
              field
            }
            """
        )
    }

    @Test func multipleAnonOperations() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            {
              fieldA
            }
            {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 1)],
            message: "This anonymous operation must be the only defined operation."
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 4, column: 1)],
            message: "This anonymous operation must be the only defined operation."
        )
    }

    @Test func anonOperationWithAMutation() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              fieldA
            }
            mutation Foo {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 1)],
            message: "This anonymous operation must be the only defined operation."
        )
    }

    @Test func anonOperationWithASubscription() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              fieldA
            }
            subscription Foo {
              fieldB
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 1)],
            message: "This anonymous operation must be the only defined operation."
        )
    }
}
