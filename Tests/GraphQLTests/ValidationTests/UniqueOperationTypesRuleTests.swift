@testable import GraphQL
import Testing

class UniqueOperationTypesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueOperationTypesRule
    }

    @Test func noSchemaDefinition() throws {
        try assertValidationErrors(
            """
            type Foo
            """,
            []
        )
    }

    @Test func schemaDefinitionWithAllTypes() throws {
        try assertValidationErrors(
            """
            type Foo

            schema {
              query: Foo
              mutation: Foo
              subscription: Foo
            }
            """,
            []
        )
    }

    @Test func schemaDefinitionWithSingleExtension() throws {
        try assertValidationErrors(
            """
            type Foo

            schema { query: Foo }

            extend schema {
              mutation: Foo
              subscription: Foo
            }
            """,
            []
        )
    }

    @Test func schemaDefinitionWithSeparateExtensions() throws {
        try assertValidationErrors(
            """
            type Foo

            schema { query: Foo }
            extend schema { mutation: Foo }
            extend schema { subscription: Foo }
            """,
            []
        )
    }

    @Test func extendSchemaBeforeDefinition() throws {
        try assertValidationErrors(
            """
            type Foo

            extend schema { mutation: Foo }
            extend schema { subscription: Foo }

            schema { query: Foo }
            """,
            []
        )
    }

    @Test func duplicateOperationTypesInsideSingleSchemaDefinition() throws {
        try assertValidationErrors(
            """
            type Foo

            schema {
              query: Foo
              mutation: Foo
              subscription: Foo

              query: Foo
              mutation: Foo
              subscription: Foo
            }
            """,
            [
                GraphQLError(
                    message: "There can be only one query type in schema.",
                    locations: [
                        .init(line: 4, column: 3),
                        .init(line: 8, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one mutation type in schema.",
                    locations: [
                        .init(line: 5, column: 3),
                        .init(line: 9, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one subscription type in schema.",
                    locations: [
                        .init(line: 6, column: 3),
                        .init(line: 10, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func duplicateOperationTypesInsideSingleSchemaDefinitionTwice() throws {
        try assertValidationErrors(
            """
            type Foo

            schema {
              query: Foo
              mutation: Foo
              subscription: Foo
            }

            extend schema {
              query: Foo
              mutation: Foo
              subscription: Foo
            }

            extend schema {
              query: Foo
              mutation: Foo
              subscription: Foo
            }
            """,
            [
                GraphQLError(
                    message: "There can be only one query type in schema.",
                    locations: [
                        .init(line: 4, column: 3),
                        .init(line: 10, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one mutation type in schema.",
                    locations: [
                        .init(line: 5, column: 3),
                        .init(line: 11, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one subscription type in schema.",
                    locations: [
                        .init(line: 6, column: 3),
                        .init(line: 12, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one query type in schema.",
                    locations: [
                        .init(line: 4, column: 3),
                        .init(line: 16, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one mutation type in schema.",
                    locations: [
                        .init(line: 5, column: 3),
                        .init(line: 17, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one subscription type in schema.",
                    locations: [
                        .init(line: 6, column: 3),
                        .init(line: 18, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func duplicateOperationTypesInsideSecondSchemaExtension() throws {
        try assertValidationErrors(
            """
            type Foo

            schema {
              query: Foo
            }

            extend schema {
              mutation: Foo
              subscription: Foo
            }

            extend schema {
              query: Foo
              mutation: Foo
              subscription: Foo
            }
            """,
            [
                GraphQLError(
                    message: "There can be only one query type in schema.",
                    locations: [
                        .init(line: 4, column: 3),
                        .init(line: 13, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one mutation type in schema.",
                    locations: [
                        .init(line: 8, column: 3),
                        .init(line: 14, column: 3),
                    ]
                ),
                GraphQLError(
                    message: "There can be only one subscription type in schema.",
                    locations: [
                        .init(line: 9, column: 3),
                        .init(line: 15, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func defineAndExtendSchemaInsideExtensionSDL() throws {
        let schema = try buildSchema(source: "type Foo")
        let sdl = """
        schema { query: Foo }
        extend schema { mutation: Foo }
        extend schema { subscription: Foo }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func addingNewOperationTypesToExistingSchema() throws {
        let schema = try buildSchema(source: "type Query")
        let sdl = """
        extend schema { mutation: Foo }
        extend schema { subscription: Foo }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func addingConflictingOperationTypesToExistingSchema() throws {
        let schema = try buildSchema(source: """
        type Query
        type Mutation
        type Subscription

        type Foo
        """)
        let sdl = """
        extend schema {
          query: Foo
          mutation: Foo
          subscription: Foo
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: "Type for query already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 2, column: 3)]
                ),
                GraphQLError(
                    message: "Type for mutation already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 3, column: 3)]
                ),
                GraphQLError(
                    message: "Type for subscription already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 4, column: 3)]
                ),
            ]
        )
    }

    @Test func addingConflictingOperationTypesToExistingSchemaTwice() throws {
        let schema = try buildSchema(source: """
        type Query
        type Mutation
        type Subscription
        """)
        let sdl = """
        extend schema {
          query: Foo
          mutation: Foo
          subscription: Foo
        }

        extend schema {
          query: Foo
          mutation: Foo
          subscription: Foo
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: "Type for query already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 2, column: 3)]
                ),
                GraphQLError(
                    message: "Type for mutation already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 3, column: 3)]
                ),
                GraphQLError(
                    message: "Type for subscription already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 4, column: 3)]
                ),
                GraphQLError(
                    message: "Type for query already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 8, column: 3)]
                ),
                GraphQLError(
                    message: "Type for mutation already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 9, column: 3)]
                ),
                GraphQLError(
                    message: "Type for subscription already defined in the schema. It cannot be redefined.",
                    locations: [.init(line: 10, column: 3)]
                ),
            ]
        )
    }
}
