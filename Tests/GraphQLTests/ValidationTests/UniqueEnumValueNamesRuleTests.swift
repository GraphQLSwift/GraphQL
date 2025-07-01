@testable import GraphQL
import Testing

class UniqueEnumValueNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueEnumValueNamesRule
    }

    @Test func testNoValues() throws {
        try assertValidationErrors(
            """
            enum SomeEnum
            """,
            []
        )
    }

    @Test func testOneValue() throws {
        try assertValidationErrors(
            """
            enum SomeEnum {
              FOO
            }
            """,
            []
        )
    }

    @Test func testMultipleValues() throws {
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

    @Test func testDuplicateValuesInsideTheSameEnumDefinition() throws {
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

    @Test func testExtendEnumWithNewValue() throws {
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

    @Test func testExtendEnumWithDuplicateValue() throws {
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

    @Test func testDuplicateValueInsideExtension() throws {
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

    @Test func testDuplicateValueInsideDifferentExtension() throws {
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

    @Test func testAddingNewValueToTheTypeInsideExistingSchema() throws {
        let schema = try buildSchema(source: "enum SomeEnum")
        let sdl = """
        extend enum SomeEnum {
          FOO
        }
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func testAddingConflictingValueToExistingSchemaTwice() throws {
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

    @Test func testAddingEnumValuesToExistingSchemaTwice() throws {
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
