@testable import GraphQL
import Testing

class ExecutableDefinitionsRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = ExecutableDefinitionsRule
    }

    @Test func withOnlyOperation() throws {
        try assertValid(
            """
            query Foo {
              dog {
                name
              }
            }
            """
        )
    }

    @Test func withOperationAndFragment() throws {
        try assertValid(
            """
            query Foo {
              dog {
                name
                ...Frag
              }
            }

            fragment Frag on Dog {
              name
            }
            """
        )
    }

    @Test func withTypeDefinition() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo {
              dog {
                name
              }
            }

            type Cow {
              name: String
            }

            extend type Dog {
              color: String
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 7, column: 1)],
            message: #"The "Cow" definition is not executable."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 11, column: 1)],
            message: #"The "Dog" definition is not executable."#
        )
    }

    @Test func withSchemaDefinition() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query: """
            schema {
              query: Query
            }

            type Query {
              test: String
            }

            extend schema @directive
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 1)],
            message: #"The schema definition is not executable."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 5, column: 1)],
            message: #"The "Query" definition is not executable."#
        )
        try assertValidationError(
            error: errors[2],
            locations: [(line: 9, column: 1)],
            message: #"The schema definition is not executable."#
        )
    }
}
