@testable import GraphQL
import XCTest

class UniqueDirectiveNamesRuleTests: SDLValidationTestCase {
    override func setUp() {
        rule = UniqueDirectiveNamesRule
    }

    func testNoDirective() throws {
        try assertValidationErrors(
            """
            type Foo
            """,
            []
        )
    }

    func testOneDirective() throws {
        try assertValidationErrors(
            """
            directive @foo on SCHEMA
            """,
            []
        )
    }

    func testManyDirectives() throws {
        try assertValidationErrors(
            """
            directive @foo on SCHEMA
            directive @bar on SCHEMA
            directive @baz on SCHEMA
            """,
            []
        )
    }

    func testDirectiveAndNonDirectiveDefinitionsNamedTheSame() throws {
        try assertValidationErrors(
            """
            query foo { __typename }
            fragment foo on foo { __typename }
            type foo

            directive @foo on SCHEMA
            """,
            []
        )
    }

    func testDirectivesNamedTheSame() throws {
        try assertValidationErrors(
            """
            directive @foo on SCHEMA

            directive @foo on SCHEMA
            """,
            [
                GraphQLError(
                    message: #"There can be only one directive named "@foo"."#,
                    locations: [
                        .init(line: 1, column: 12),
                        .init(line: 3, column: 12),
                    ]
                ),
            ]
        )
    }

    func testAddingNewDirectiveToExistingSchema() throws {
        let schema = try buildSchema(source: "directive @foo on SCHEMA")
        try assertValidationErrors("directive @bar on SCHEMA", schema: schema, [])
    }

    func testAddingNewDirectiveWithStandardNameToExistingSchema() throws {
        let schema = try buildSchema(source: "type foo")
        try assertValidationErrors(
            "directive @skip on SCHEMA",
            schema: schema,
            [
                GraphQLError(
                    message: #"Directive "@skip" already exists in the schema. It cannot be redefined."#,
                    locations: [.init(line: 1, column: 12)]
                ),
            ]
        )
    }

    func testAddingNewDirectiveToExistingSchemaWithSameNamedType() throws {
        let schema = try buildSchema(source: "type foo")
        try assertValidationErrors("directive @foo on SCHEMA", schema: schema, [])
    }

    func testAddingConflictingDirectiveToExistingSchema() throws {
        let schema = try buildSchema(source: "directive @foo on SCHEMA")
        try assertValidationErrors(
            "directive @foo on SCHEMA",
            schema: schema,
            [
                GraphQLError(
                    message: #"Directive "@foo" already exists in the schema. It cannot be redefined."#,
                    locations: [.init(line: 1, column: 12)]
                ),
            ]
        )
    }
}
