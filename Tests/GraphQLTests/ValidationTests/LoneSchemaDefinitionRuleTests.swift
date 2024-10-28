@testable import GraphQL
import XCTest

class LoneSchemaDefinitionRuleTests: SDLValidationTestCase {
    override func setUp() {
        rule = LoneSchemaDefinitionRule
    }

    func testNoSchema() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String
            }
            """,
            []
        )
    }

    func testOneSchemaDefinition() throws {
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

    func testMultipleSchemaDefinitions() throws {
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

    func testDefineSchemaInSchemaExtension() throws {
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

    func testRedefineSchemaInSchemaExtension() throws {
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

    func testRedefineImplicitSchemaInSchemaExtension() throws {
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

    func testExtendSchemaInSchemaExtension() throws {
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
