@testable import GraphQL
import Testing

class UniqueDirectiveNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueDirectiveNamesRule
    }

    @Test func noDirective() throws {
        try assertValidationErrors(
            """
            type Foo
            """,
            []
        )
    }

    @Test func oneDirective() throws {
        try assertValidationErrors(
            """
            directive @foo on SCHEMA
            """,
            []
        )
    }

    @Test func manyDirectives() throws {
        try assertValidationErrors(
            """
            directive @foo on SCHEMA
            directive @bar on SCHEMA
            directive @baz on SCHEMA
            """,
            []
        )
    }

    @Test func directiveAndNonDirectiveDefinitionsNamedTheSame() throws {
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

    @Test func directivesNamedTheSame() throws {
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

    @Test func addingNewDirectiveToExistingSchema() throws {
        let schema = try buildSchema(source: "directive @foo on SCHEMA")
        try assertValidationErrors("directive @bar on SCHEMA", schema: schema, [])
    }

    @Test func addingNewDirectiveWithStandardNameToExistingSchema() throws {
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

    @Test func addingNewDirectiveToExistingSchemaWithSameNamedType() throws {
        let schema = try buildSchema(source: "type foo")
        try assertValidationErrors("directive @foo on SCHEMA", schema: schema, [])
    }

    @Test func addingConflictingDirectiveToExistingSchema() throws {
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
