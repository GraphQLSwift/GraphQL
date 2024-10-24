@testable import GraphQL
import XCTest

class KnownArgumentNamesOnDirectivesRuleTests: SDLValidationTestCase {
    override func setUp() {
        rule = KnownArgumentNamesOnDirectivesRule
    }

    func testKnownArgOnDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test(arg: "")
            }

            directive @test(arg: String) on FIELD_DEFINITION
            """,
            []
        )
    }

    func testUnknownArgOnDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test(unknown: "")
            }

            directive @test(arg: String) on FIELD_DEFINITION
            """,
            [
                GraphQLError(
                    message: #"Unknown argument "unknown" on directive "@test"."#,
                    locations: [.init(line: 2, column: 21)]
                ),
            ]
        )
    }

    func testMisspelledArgNameIsReportedOnDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test(agr: "")
            }

            directive @test(arg: String) on FIELD_DEFINITION
            """,
            [
                GraphQLError(
                    message: #"Unknown argument "agr" on directive "@test". Did you mean "arg"?"#,
                    locations: [.init(line: 2, column: 21)]
                ),
            ]
        )
    }

    func testUnknownArgOnStandardDirective() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @deprecated(unknown: "")
            }
            """,
            [
                GraphQLError(
                    message: #"Unknown argument "unknown" on directive "@deprecated"."#,
                    locations: [.init(line: 2, column: 27)]
                ),
            ]
        )
    }

    func testUnknownArgOnOverriddenStandardDirective() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @deprecated(reason: "")
            }
            directive @deprecated(arg: String) on FIELD
            """,
            [
                GraphQLError(
                    message: #"Unknown argument "reason" on directive "@deprecated"."#,
                    locations: [.init(line: 2, column: 27)]
                ),
            ]
        )
    }

    func testUnknownArgOnDirectiveDefinedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: String
        }
        """)
        let sdl = """
        directive @test(arg: String) on OBJECT

        extend type Query  @test(unknown: "")
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Unknown argument "unknown" on directive "@test"."#,
                    locations: [.init(line: 3, column: 26)]
                ),
            ]
        )
    }

    func testUnknownArgOnDirectiveUsedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        directive @test(arg: String) on OBJECT

        type Query {
          foo: String
        }
        """)
        let sdl = """
        extend type Query @test(unknown: "")
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Unknown argument "unknown" on directive "@test"."#,
                    locations: [.init(line: 1, column: 25)]
                ),
            ]
        )
    }
}
