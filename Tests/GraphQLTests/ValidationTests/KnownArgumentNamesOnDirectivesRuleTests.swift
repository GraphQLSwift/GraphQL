@testable import GraphQL
import Testing

class KnownArgumentNamesOnDirectivesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = KnownArgumentNamesOnDirectivesRule
    }

    @Test func knownArgOnDirectiveDefinedInsideSDL() throws {
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

    @Test func unknownArgOnDirectiveDefinedInsideSDL() throws {
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

    @Test func misspelledArgNameIsReportedOnDirectiveDefinedInsideSDL() throws {
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

    @Test func unknownArgOnStandardDirective() throws {
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

    @Test func unknownArgOnOverriddenStandardDirective() throws {
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

    @Test func unknownArgOnDirectiveDefinedInSchemaExtension() throws {
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

    @Test func unknownArgOnDirectiveUsedInSchemaExtension() throws {
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
