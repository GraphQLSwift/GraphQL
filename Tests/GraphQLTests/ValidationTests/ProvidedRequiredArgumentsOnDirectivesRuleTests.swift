@testable import GraphQL
import XCTest

class ProvidedRequiredArgumentsOnDirectivesRuleTests: SDLValidationTestCase {
    override func setUp() {
        rule = ProvidedRequiredArgumentsOnDirectivesRule
    }

    func testMissingOptionalArgsOnDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test
            }

            directive @test(arg1: String, arg2: String! = "") on FIELD_DEFINITION
            """,
            []
        )
    }

    func testMissingArgOnDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test
            }

            directive @test(arg: String!) on FIELD_DEFINITION
            """,
            [
                GraphQLError(
                    message: #"Argument "@test(arg:)" of type "String!" is required, but it was not provided."#,
                    locations: [.init(line: 2, column: 15)]
                ),
            ]
        )
    }

    func testMissingArgOnStandardDirective() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @include
            }
            """,
            [
                GraphQLError(
                    message: #"Argument "@include(if:)" of type "Boolean!" is required, but it was not provided."#,
                    locations: [.init(line: 2, column: 15)]
                ),
            ]
        )
    }

    func testMissingArgOnOveriddenStandardDirective() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @deprecated
            }
            directive @deprecated(reason: String!) on FIELD
            """,
            [
                GraphQLError(
                    message: #"Argument "@deprecated(reason:)" of type "String!" is required, but it was not provided."#,
                    locations: [.init(line: 2, column: 15)]
                ),
            ]
        )
    }

    func testMissingArgOnDirectiveDefinedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: String
        }
        """)
        let sdl = """
        directive @test(arg: String!) on OBJECT

        extend type Query  @test
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Argument "@test(arg:)" of type "String!" is required, but it was not provided."#,
                    locations: [.init(line: 3, column: 20)]
                ),
            ]
        )
    }

    func testMissingArgOnDirectiveUsedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        directive @test(arg: String!) on OBJECT

        type Query {
          foo: String
        }
        """)
        let sdl = """
        extend type Query @test
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Argument "@test(arg:)" of type "String!" is required, but it was not provided."#,
                    locations: [.init(line: 1, column: 19)]
                ),
            ]
        )
    }
}
