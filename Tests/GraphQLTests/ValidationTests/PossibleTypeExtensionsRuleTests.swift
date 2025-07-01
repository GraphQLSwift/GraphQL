@testable import GraphQL
import Testing

class PossibleTypeExtensionsRuleTests: SDLValidationTestCase {
    override init() {
        super.init()
        rule = PossibleTypeExtensionsRule
    }

    @Test func testNoExtensions() throws {
        try assertValidationErrors(
            """
            scalar FooScalar
            type FooObject
            interface FooInterface
            union FooUnion
            enum FooEnum
            input FooInputObject
            """,
            []
        )
    }

    @Test func testOneExtensionPerType() throws {
        try assertValidationErrors(
            """
            scalar FooScalar
            type FooObject
            interface FooInterface
            union FooUnion
            enum FooEnum
            input FooInputObject

            extend scalar FooScalar @dummy
            extend type FooObject @dummy
            extend interface FooInterface @dummy
            extend union FooUnion @dummy
            extend enum FooEnum @dummy
            extend input FooInputObject @dummy
            """,
            []
        )
    }

    @Test func testManyExtensionsPerType() throws {
        try assertValidationErrors(
            """
            scalar FooScalar
            type FooObject
            interface FooInterface
            union FooUnion
            enum FooEnum
            input FooInputObject

            extend scalar FooScalar @dummy
            extend type FooObject @dummy
            extend interface FooInterface @dummy
            extend union FooUnion @dummy
            extend enum FooEnum @dummy
            extend input FooInputObject @dummy

            extend scalar FooScalar @dummy
            extend type FooObject @dummy
            extend interface FooInterface @dummy
            extend union FooUnion @dummy
            extend enum FooEnum @dummy
            extend input FooInputObject @dummy
            """,
            []
        )
    }

    @Test func testExtendingUnknownType() throws {
        try assertValidationErrors(
            """
            type Known

            extend scalar Unknown @dummy
            extend type Unknown @dummy
            extend interface Unknown @dummy
            extend union Unknown @dummy
            extend enum Unknown @dummy
            extend input Unknown @dummy
            """,
            [
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 3, column: 15)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 4, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 5, column: 18)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 6, column: 14)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 7, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 8, column: 14)]
                ),
            ]
        )
    }

    @Test func testDoesNotConsiderNonTypeDefinitions() throws {
        try assertValidationErrors(
            """
            query Foo { __typename }
            fragment Foo on Query { __typename }
            directive @Foo on SCHEMA

            extend scalar Foo @dummy
            extend type Foo @dummy
            extend interface Foo @dummy
            extend union Foo @dummy
            extend enum Foo @dummy
            extend input Foo @dummy
            """,
            [
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 5, column: 15)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 6, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 7, column: 18)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 8, column: 14)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 9, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Foo" because it is not defined."#,
                    locations: [.init(line: 10, column: 14)]
                ),
            ]
        )
    }

    @Test func testExtendingWithDifferentKinds() throws {
        try assertValidationErrors(
            """
            scalar FooScalar
            type FooObject
            interface FooInterface
            union FooUnion
            enum FooEnum
            input FooInputObject

            extend type FooScalar @dummy
            extend interface FooObject @dummy
            extend union FooInterface @dummy
            extend enum FooUnion @dummy
            extend input FooEnum @dummy
            extend scalar FooInputObject @dummy
            """,
            [
                GraphQLError(
                    message: #"Cannot extend non-object type "FooScalar"."#,
                    locations: [
                        .init(line: 1, column: 1),
                        .init(line: 8, column: 1),
                    ]
                ),
                GraphQLError(
                    message: #"Cannot extend non-interface type "FooObject"."#,
                    locations: [
                        .init(line: 2, column: 1),
                        .init(line: 9, column: 1),
                    ]
                ),
                GraphQLError(
                    message: #"Cannot extend non-union type "FooInterface"."#,
                    locations: [
                        .init(line: 3, column: 1),
                        .init(line: 10, column: 1),
                    ]
                ),
                GraphQLError(
                    message: #"Cannot extend non-enum type "FooUnion"."#,
                    locations: [
                        .init(line: 4, column: 1),
                        .init(line: 11, column: 1),
                    ]
                ),
                GraphQLError(
                    message: #"Cannot extend non-input object type "FooEnum"."#,
                    locations: [
                        .init(line: 5, column: 1),
                        .init(line: 12, column: 1),
                    ]
                ),
                GraphQLError(
                    message: #"Cannot extend non-scalar type "FooInputObject"."#,
                    locations: [
                        .init(line: 6, column: 1),
                        .init(line: 13, column: 1),
                    ]
                ),
            ]
        )
    }

    @Test func testExtendingTypesWithinExistingSchema() throws {
        let schema = try buildSchema(source: """
        scalar FooScalar
        type FooObject
        interface FooInterface
        union FooUnion
        enum FooEnum
        input FooInputObject
        """)
        let sdl = """
        extend scalar FooScalar @dummy
        extend type FooObject @dummy
        extend interface FooInterface @dummy
        extend union FooUnion @dummy
        extend enum FooEnum @dummy
        extend input FooInputObject @dummy
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    @Test func testExtendingUnknownTypesWithinExistingSchema() throws {
        let schema = try buildSchema(source: "type Known")
        let sdl = """
        extend scalar Unknown @dummy
        extend type Unknown @dummy
        extend interface Unknown @dummy
        extend union Unknown @dummy
        extend enum Unknown @dummy
        extend input Unknown @dummy
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 1, column: 15)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 2, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 3, column: 18)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 4, column: 14)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 5, column: 13)]
                ),
                GraphQLError(
                    message: #"Cannot extend type "Unknown" because it is not defined. Did you mean "Known"?"#,
                    locations: [.init(line: 6, column: 14)]
                ),
            ]
        )
    }

    @Test func testExtendingTypesWithDifferentKindsWithinExistingSchema() throws {
        let schema = try buildSchema(source: """
        scalar FooScalar
        type FooObject
        interface FooInterface
        union FooUnion
        enum FooEnum
        input FooInputObject
        """)
        let sdl = """
        extend type FooScalar @dummy
        extend interface FooObject @dummy
        extend union FooInterface @dummy
        extend enum FooUnion @dummy
        extend input FooEnum @dummy
        extend scalar FooInputObject @dummy
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Cannot extend non-object type "FooScalar"."#,
                    locations: [.init(line: 1, column: 1)]
                ),
                GraphQLError(
                    message: #"Cannot extend non-interface type "FooObject"."#,
                    locations: [.init(line: 2, column: 1)]
                ),
                GraphQLError(
                    message: #"Cannot extend non-union type "FooInterface"."#,
                    locations: [.init(line: 3, column: 1)]
                ),
                GraphQLError(
                    message: #"Cannot extend non-enum type "FooUnion"."#,
                    locations: [.init(line: 4, column: 1)]
                ),
                GraphQLError(
                    message: #"Cannot extend non-input object type "FooEnum"."#,
                    locations: [.init(line: 5, column: 1)]
                ),
                GraphQLError(
                    message: #"Cannot extend non-scalar type "FooInputObject"."#,
                    locations: [.init(line: 6, column: 1)]
                ),
            ]
        )
    }
}
