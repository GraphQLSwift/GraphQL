@testable import GraphQL
import Testing

class UniqueTypeNamesRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = UniqueTypeNamesRule
    }

    @Test func noTypes() throws {
        try assertValidationErrors(
            """
            directive @test on SCHEMA
            """,
            []
        )
    }

    @Test func oneType() throws {
        try assertValidationErrors(
            """
            type Foo
            """,
            []
        )
    }

    @Test func manyTypes() throws {
        try assertValidationErrors(
            """
            type Foo
            type Bar
            type Baz
            """,
            []
        )
    }

    @Test func typeAndNonTypeDefinitionsNamedTheSame() throws {
        try assertValidationErrors(
            """
            query Foo { __typename }
            fragment Foo on Query { __typename }
            directive @Foo on SCHEMA

            type Foo
            """,
            []
        )
    }

    @Test func typesNamedTheSame() throws {
        try assertValidationErrors(
            """
            type Foo

            scalar Foo
            type Foo
            interface Foo
            union Foo
            enum Foo
            input Foo
            """,
            [
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 3, column: 8),
                    ]
                ),
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 4, column: 6),
                    ]
                ),
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 5, column: 11),
                    ]
                ),
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 6, column: 7),
                    ]
                ),
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 7, column: 6),
                    ]
                ),
                GraphQLError(
                    message: #"There can be only one type named "Foo"."#,
                    locations: [
                        .init(line: 1, column: 6),
                        .init(line: 8, column: 7),
                    ]
                ),
            ]
        )
    }

    @Test func addingNewTypeToExistingSchema() throws {
        let schema = try buildSchema(source: "type Foo")
        try assertValidationErrors("type Bar", schema: schema, [])
    }

    @Test func addingNewTypeToExistingSchemaWithSameNamedDirective() throws {
        let schema = try buildSchema(source: "directive @Foo on SCHEMA")
        try assertValidationErrors("type Foo", schema: schema, [])
    }

    @Test func addingConflictingTypesToExistingSchema() throws {
        let schema = try buildSchema(source: "type Foo")
        let sdl = """
        scalar Foo
        type Foo
        interface Foo
        union Foo
        enum Foo
        input Foo
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 1, column: 8)]
                ),
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 2, column: 6)]
                ),
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 3, column: 11)]
                ),
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 4, column: 7)]
                ),
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 5, column: 6)]
                ),
                GraphQLError(
                    message: #"Type "Foo" already exists in the schema. It cannot also be defined in this type definition."#,
                    locations: [.init(line: 6, column: 7)]
                ),
            ]
        )
    }
}
