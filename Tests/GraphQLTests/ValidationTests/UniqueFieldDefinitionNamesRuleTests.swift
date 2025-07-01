@testable import GraphQL
import Testing

class UniqueFieldDefinitionNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueFieldDefinitionNamesRule
    }

    @Test func testNoFields() throws {
        try assertValidationErrors(
            """
            type SomeObject
            interface SomeInterface
            input SomeInputObject
            """,
            []
        )
    }

    @Test func testOneField() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              foo: String
            }

            interface SomeInterface {
              foo: String
            }

            input SomeInputObject {
              foo: String
            }
            """,
            []
        )
    }

    @Test func testMultipleFields() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              foo: String
              bar: String
            }

            interface SomeInterface {
              foo: String
              bar: String
            }

            input SomeInputObject {
              foo: String
              bar: String
            }
            """,
            []
        )
    }

    @Test func testDuplicateFieldsInsideTheSameTypeDefinition() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              foo: String
              bar: String
              foo: String
            }

            interface SomeInterface {
              foo: String
              bar: String
              foo: String
            }

            input SomeInputObject {
              foo: String
              bar: String
              foo: String
            }
            """,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 4, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" can only be defined once."#,
                    locations: [
                        .init(line: 8, column: 3),
                        .init(line: 10, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 14, column: 3),
                        .init(line: 16, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func testExtendTypeWithNewField() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              foo: String
            }
            extend type SomeObject {
              bar: String
            }
            extend type SomeObject {
              baz: String
            }

            interface SomeInterface {
              foo: String
            }
            extend interface SomeInterface {
              bar: String
            }
            extend interface SomeInterface {
              baz: String
            }

            input SomeInputObject {
              foo: String
            }
            extend input SomeInputObject {
              bar: String
            }
            extend input SomeInputObject {
              baz: String
            }
            """,
            []
        )
    }

    @Test func testExtendTypeWithDuplicateField() throws {
        try assertValidationErrors(
            """
            extend type SomeObject {
              foo: String
            }
            type SomeObject {
              foo: String
            }

            extend interface SomeInterface {
              foo: String
            }
            interface SomeInterface {
              foo: String
            }

            extend input SomeInputObject {
              foo: String
            }
            input SomeInputObject {
              foo: String
            }
            """,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" can only be defined once."#,
                    locations: [
                        .init(line: 9, column: 3),
                        .init(line: 12, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 16, column: 3),
                        .init(line: 19, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func testDuplicateFieldInsideExtension() throws {
        try assertValidationErrors(
            """
            type SomeObject
            extend type SomeObject {
              foo: String
              bar: String
              foo: String
            }

            interface SomeInterface
            extend interface SomeInterface {
              foo: String
              bar: String
              foo: String
            }

            input SomeInputObject
            extend input SomeInputObject {
              foo: String
              bar: String
              foo: String
            }
            """,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 3, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" can only be defined once."#,
                    locations: [
                        .init(line: 10, column: 3),
                        .init(line: 12, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 17, column: 3),
                        .init(line: 19, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func testDuplicateValueInsideDifferentExtension() throws {
        try assertValidationErrors(
            """
            type SomeObject
            extend type SomeObject {
              foo: String
            }
            extend type SomeObject {
              foo: String
            }

            interface SomeInterface
            extend interface SomeInterface {
              foo: String
            }
            extend interface SomeInterface {
              foo: String
            }

            input SomeInputObject
            extend input SomeInputObject {
              foo: String
            }
            extend input SomeInputObject {
              foo: String
            }
            """,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 3, column: 3),
                        .init(line: 6, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" can only be defined once."#,
                    locations: [
                        .init(line: 11, column: 3),
                        .init(line: 14, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 19, column: 3),
                        .init(line: 22, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func testAddingNewFieldToTheTypeInsideExistingSchema() throws {
        let schema = try buildSchema(source: """
        type SomeObject
        interface SomeInterface
        input SomeInputObject
        """)
        let sdl = """
        extend type SomeObject {
          foo: String
        }

        extend interface SomeInterface {
          foo: String
        }

        extend input SomeInputObject {
          foo: String
        }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func testAddingConflictingFieldsToExistingSchemaTwice() throws {
        let schema = try buildSchema(source: """
        type SomeObject {
          foo: String
        }

        interface SomeInterface {
          foo: String
        }

        input SomeInputObject {
          foo: String
        }
        """)
        let sdl = """
        extend type SomeObject {
          foo: String
        }
        extend interface SomeInterface {
          foo: String
        }
        extend input SomeInputObject {
          foo: String
        }

        extend type SomeObject {
          foo: String
        }
        extend interface SomeInterface {
          foo: String
        }
        extend input SomeInputObject {
          foo: String
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 2, column: 3)]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 5, column: 3)]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 8, column: 3)]
                ),
                GraphQLError(
                    message: #"Field "SomeObject.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 12, column: 3)]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 15, column: 3)]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [.init(line: 18, column: 3)]
                ),
            ]
        )
    }

    @Test func testAddingFieldsToExistingSchemaTwice() throws {
        let schema = try buildSchema(source: """
        type SomeObject
        interface SomeInterface
        input SomeInputObject
        """)
        let sdl = """
        extend type SomeObject {
          foo: String
        }
        extend type SomeObject {
          foo: String
        }

        extend interface SomeInterface {
          foo: String
        }
        extend interface SomeInterface {
          foo: String
        }

        extend input SomeInputObject {
          foo: String
        }
        extend input SomeInputObject {
          foo: String
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Field "SomeObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInterface.foo" can only be defined once."#,
                    locations: [
                        .init(line: 9, column: 3),
                        .init(line: 12, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Field "SomeInputObject.foo" can only be defined once."#,
                    locations: [
                        .init(line: 16, column: 3),
                        .init(line: 19, column: 3),
                    ]
                ),
            ]
        )
    }
}
