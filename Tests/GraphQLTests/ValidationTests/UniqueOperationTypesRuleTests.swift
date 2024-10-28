@testable import GraphQL
import XCTest

class UniqueOperationTypesRuleTests: SDLValidationTestCase {
    override func setUp() {
        rule = UniqueOperationTypesRule
    }

    func testNoSchemaDefinition() throws {
        try assertValidationErrors(
            """
            type Foo
            """,
            []
        )
    }

    func testSchemaDefinitionWithAllTypes() throws {
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

    func testSchemaDefinitionWithSingleExtension() throws {
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

    func testSchemaDefinitionWithSeparateExtensions() throws {
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

    func testExtendSchemaBeforeDefinition() throws {
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

    func testDuplicateOperationTypesInsideSingleSchemaDefinition() throws {
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

    func testDuplicateOperationTypesInsideSingleSchemaDefinitionTwice() throws {
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

    func testDuplicateOperationTypesInsideSecondSchemaExtension() throws {
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

    func testDefineAndExtendSchemaInsideExtensionSDL() throws {
        let schema = try buildSchema(source: "type Foo")
        let sdl = """
        schema { query: Foo }
        extend schema { mutation: Foo }
        extend schema { subscription: Foo }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    func testAddingNewOperationTypesToExistingSchema() throws {
        let schema = try buildSchema(source: "type Query")
        let sdl = """
        extend schema { mutation: Foo }
        extend schema { subscription: Foo }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    func testAddingConflictingOperationTypesToExistingSchema() throws {
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

    func testAddingConflictingOperationTypesToExistingSchemaTwice() throws {
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
