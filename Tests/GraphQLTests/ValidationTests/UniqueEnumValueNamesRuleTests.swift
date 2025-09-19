@testable import GraphQL
import Testing

class UniqueEnumValueNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueEnumValueNamesRule
    }

    @Test func noValues() throws {
        try assertValidationErrors(
            """
            enum SomeEnum
            """,
            []
        )
    }

    @Test func oneValue() throws {
        try assertValidationErrors(
            """
            enum SomeEnum {
              FOO
            }
            """,
            []
        )
    }

    @Test func multipleValues() throws {
        try assertValidationErrors(
            """
            enum SomeEnum {
              FOO
              BAR
            }
            """,
            []
        )
    }

    @Test func duplicateValuesInsideTheSameEnumDefinition() throws {
        try assertValidationErrors(
            """
            enum SomeEnum {
              FOO
              BAR
              FOO
            }
            """,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 4, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func extendEnumWithNewValue() throws {
        try assertValidationErrors(
            """
            enum SomeEnum {
              FOO
            }
            extend enum SomeEnum {
              BAR
            }
            extend enum SomeEnum {
              BAZ
            }
            """,
            []
        )
    }

    @Test func extendEnumWithDuplicateValue() throws {
        try assertValidationErrors(
            """
            extend enum SomeEnum {
              FOO
            }
            enum SomeEnum {
              FOO
            }
            """,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func duplicateValueInsideExtension() throws {
        try assertValidationErrors(
            """
            enum SomeEnum
            extend enum SomeEnum {
              FOO
              BAR
              FOO
            }
            """,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" can only be defined once."#,
                    locations: [
                        .init(line: 3, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func duplicateValueInsideDifferentExtension() throws {
        try assertValidationErrors(
            """
            enum SomeEnum
            extend enum SomeEnum {
              FOO
            }
            extend enum SomeEnum {
              FOO
            }
            """,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" can only be defined once."#,
                    locations: [
                        .init(line: 3, column: 3),
                        .init(line: 6, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func addingNewValueToTheTypeInsideExistingSchema() throws {
        let schema = try buildSchema(source: "enum SomeEnum")
        let sdl = """
        extend enum SomeEnum {
          FOO
        }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func addingConflictingValueToExistingSchemaTwice() throws {
        let schema = try buildSchema(source: """
        enum SomeEnum {
          FOO
        }
        """)
        let sdl = """
        extend enum SomeEnum {
          FOO
        }
        extend enum SomeEnum {
          FOO
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [
                        .init(line: 2, column: 3),
                    ]
                ),
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" already exists in the schema. It cannot also be defined in this type extension."#,
                    locations: [
                        .init(line: 5, column: 3),
                    ]
                ),
            ]
        )
    }

    @Test func addingEnumValuesToExistingSchemaTwice() throws {
        let schema = try buildSchema(source: "enum SomeEnum")
        let sdl = """
        extend enum SomeEnum {
          FOO
        }
        extend enum SomeEnum {
          FOO
        }
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Enum value "SomeEnum.FOO" can only be defined once."#,
                    locations: [
                        .init(line: 2, column: 3),
                        .init(line: 5, column: 3),
                    ]
                ),
            ]
        )
    }
}
