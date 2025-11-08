@testable import GraphQL
import Testing

class LoneSchemaDefinitionRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = LoneSchemaDefinitionRule
    }

    @Test func noSchema() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String
            }
            """,
            []
        )
    }

    @Test func oneSchemaDefinition() throws {
        try assertValidationErrors(
            """
            schema {
              query: Foo
            }

            type Foo {
              foo: String
            }
            """,
            []
        )
    }

    @Test func multipleSchemaDefinitions() throws {
        try assertValidationErrors(
            """
            schema {
              query: Foo
            }

            type Foo {
              foo: String
            }

            schema {
              mutation: Foo
            }

            schema {
              subscription: Foo
            }
            """,
            [
                GraphQLError(
                    message: "Must provide only one schema definition.",
                    locations: [.init(line: 9, column: 1)]
                ),
                GraphQLError(
                    message: "Must provide only one schema definition.",
                    locations: [.init(line: 13, column: 1)]
                ),
            ]
        )
    }

    @Test func defineSchemaInSchemaExtension() throws {
        let schema = try buildSchema(source: """
          type Foo {
            foo: String
          }
        """)

        try assertValidationErrors(
            """
              schema {
                query: Foo
              }
            """,
            schema: schema,
            []
        )
    }

    @Test func redefineSchemaInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        schema {
          query: Foo
        }

        type Foo {
          foo: String
        }
        """)

        try assertValidationErrors(
            """
            schema {
              mutation: Foo
            }
            """,
            schema: schema,
            [
                GraphQLError(
                    message: "Cannot define a new schema within a schema extension.",
                    locations: [.init(line: 1, column: 1)]
                ),
            ]
        )
    }

    @Test func redefineImplicitSchemaInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          fooField: Foo
        }

        type Foo {
          foo: String
        }
        """)

        try assertValidationErrors(
            """
            schema {
              mutation: Foo
            }
            """,
            schema: schema,
            [
                GraphQLError(
                    message: "Cannot define a new schema within a schema extension.",
                    locations: [.init(line: 1, column: 1)]
                ),
            ]
        )
    }

    @Test func extendSchemaInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          fooField: Foo
        }

        type Foo {
          foo: String
        }
        """)

        try assertValidationErrors(
            """
            extend schema {
              mutation: Foo
            }
            """,
            schema: schema,
            []
        )
    }
}
