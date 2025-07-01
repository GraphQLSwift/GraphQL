@testable import GraphQL
import Testing

class UniqueArgumentDefinitionNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueArgumentDefinitionNamesRule
    }

    @Test func testNoArgs() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              someField: String
            }

            interface SomeInterface {
              someField: String
            }

            directive @someDirective on QUERY
            """,
            []
        )
    }

    @Test func testOneArgument() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              someField(foo: String): String
            }

            interface SomeInterface {
              someField(foo: String): String
            }

            extend type SomeObject {
              anotherField(foo: String): String
            }

            extend interface SomeInterface {
              anotherField(foo: String): String
            }

            directive @someDirective(foo: String) on QUERY
            """,
            []
        )
    }

    @Test func testMultipleArguments() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              someField(
                foo: String
                bar: String
              ): String
            }

            interface SomeInterface {
              someField(
                foo: String
                bar: String
              ): String
            }

            extend type SomeObject {
              anotherField(
                foo: String
                bar: String
              ): String
            }

            extend interface SomeInterface {
              anotherField(
                foo: String
                bar: String
              ): String
            }

            directive @someDirective(
              foo: String
              bar: String
            ) on QUERY
            """,
            []
        )
    }

    @Test func testDuplicatingArguments() throws {
        try assertValidationErrors(
            """
            type SomeObject {
              someField(
                foo: String
                bar: String
                foo: String
              ): String
            }

            interface SomeInterface {
              someField(
                foo: String
                bar: String
                foo: String
              ): String
            }

            extend type SomeObject {
              anotherField(
                foo: String
                bar: String
                bar: String
              ): String
            }

            extend interface SomeInterface {
              anotherField(
                bar: String
                foo: String
                foo: String
              ): String
            }

            directive @someDirective(
              foo: String
              bar: String
              foo: String
            ) on QUERY
            """,
            [
                GraphQLError(
                    message: #"Argument "SomeObject.someField(foo:)" can only be defined once."#,
                    locations: [
                        .init(line: 3, column: 5),
                        .init(line: 5, column: 5),
                    ]
                ),
                GraphQLError(
                    message: #"Argument "SomeInterface.someField(foo:)" can only be defined once."#,
                    locations: [
                        .init(line: 11, column: 5),
                        .init(line: 13, column: 5),
                    ]
                ),
                GraphQLError(
                    message: #"Argument "SomeObject.anotherField(bar:)" can only be defined once."#,
                    locations: [
                        .init(line: 20, column: 5),
                        .init(line: 21, column: 5),
                    ]
                ),
                GraphQLError(
                    message: #"Argument "SomeInterface.anotherField(foo:)" can only be defined once."#,
                    locations: [
                        .init(line: 28, column: 5),
                        .init(line: 29, column: 5),
                    ]
                ),
                GraphQLError(
                    message: #"Argument "@someDirective(foo:)" can only be defined once."#,
                    locations: [
                        .init(line: 34, column: 3),
                        .init(line: 36, column: 3),
                    ]
                ),
            ]
        )
    }
}
