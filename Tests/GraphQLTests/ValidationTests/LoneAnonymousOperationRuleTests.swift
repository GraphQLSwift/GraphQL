@testable import GraphQL
import Testing

class LoneAnonymousOperationRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = LoneAnonymousOperationRule
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

    @Test func testMultipleNamedOperations() throws {
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

    @Test func testAnonOperationWithFragment() throws {
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

    @Test func testMultipleAnonOperations() throws {
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

    @Test func testAnonOperationWithAMutation() throws {
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

    @Test func testAnonOperationWithASubscription() throws {
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
