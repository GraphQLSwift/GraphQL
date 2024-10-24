@testable import GraphQL
import XCTest

class KnownDirectivesRuleTests: ValidationTestCase {
    override func setUp() {
        rule = KnownDirectivesRule
    }

    func testWithNoDirectives() throws {
        try assertValid(
            """
            query Foo {
                name
                ...Frag
            }

            fragment Frag on Dog {
                name
            }
            """,
            schema: schemaWithDirectives
        )
    }

    func testWithStandardDirectives() throws {
        try assertValid(
            """
            {
                human @skip(if: false) {
                    name
                    pets {
                        ... on Dog @include(if: true) {
                            name
                        }
                    }
                }
            }
            """,
            schema: schemaWithDirectives
        )
    }

    func testWithUnknownDirective() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
                human @unknown(directive: "value") {
                    name
                }
            }
            """,
            schema: schemaWithDirectives
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 11)],
            message: "Unknown directive \"@unknown\"."
        )
    }

    func testWithManyUnknownDirectives() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            {
                __typename @unknown
                human @unknown {
                    name
                    pets @unknown {
                        name
                    }
                }
            }
            """,
            schema: schemaWithDirectives
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 16)],
            message: "Unknown directive \"@unknown\"."
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 3, column: 11)],
            message: "Unknown directive \"@unknown\"."
        )
        try assertValidationError(
            error: errors[2],
            locations: [(line: 5, column: 14)],
            message: "Unknown directive \"@unknown\"."
        )
    }

    func testWithWellPlacedDirectives() throws {
        try assertValid(
            """
            query ($var: Boolean @onVariableDefinition) @onQuery {
                human @onField {
                    ...Frag @onFragmentSpread
                    ... @onInlineFragment {
                        name @onField
                    }
                }
            }

            mutation @onMutation {
                someField @onField
            }

            subscription @onSubscription {
                someField @onField
            }

            fragment Frag on Human @onFragmentDefinition {
                name @onField
            }
            """,
            schema: schemaWithDirectives
        )
    }

    func testWithMisplacedDirectives() throws {
        let errors = try assertInvalid(
            errorCount: 12,
            query:
            """
            query ($var: Boolean @onQuery) @onMutation {
                human @onQuery {
                    ...Frag @onQuery
                    ... @onQuery {
                        name @onQuery
                    }
                }
            }

            mutation @onQuery {
                someField @onQuery
            }

            subscription @onQuery {
                someField @onQuery
            }

            fragment Frag on Human @onQuery {
                name @onQuery
            }
            """,
            schema: schemaWithDirectives
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 22)],
            message: "Directive \"@onQuery\" may not be used on VARIABLE_DEFINITION."
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 1, column: 32)],
            message: "Directive \"@onMutation\" may not be used on QUERY."
        )
        try assertValidationError(
            error: errors[2],
            locations: [(line: 2, column: 11)],
            message: "Directive \"@onQuery\" may not be used on FIELD."
        )
        try assertValidationError(
            error: errors[3],
            locations: [(line: 3, column: 17)],
            message: "Directive \"@onQuery\" may not be used on FRAGMENT_SPREAD."
        )
        try assertValidationError(
            error: errors[4],
            locations: [(line: 4, column: 13)],
            message: "Directive \"@onQuery\" may not be used on INLINE_FRAGMENT."
        )
        try assertValidationError(
            error: errors[5],
            locations: [(line: 5, column: 18)],
            message: "Directive \"@onQuery\" may not be used on FIELD."
        )
        try assertValidationError(
            error: errors[6],
            locations: [(line: 10, column: 10)],
            message: "Directive \"@onQuery\" may not be used on MUTATION."
        )
        try assertValidationError(
            error: errors[7],
            locations: [(line: 11, column: 15)],
            message: "Directive \"@onQuery\" may not be used on FIELD."
        )
        try assertValidationError(
            error: errors[8],
            locations: [(line: 14, column: 14)],
            message: "Directive \"@onQuery\" may not be used on SUBSCRIPTION."
        )
        try assertValidationError(
            error: errors[9],
            locations: [(line: 15, column: 15)],
            message: "Directive \"@onQuery\" may not be used on FIELD."
        )
        try assertValidationError(
            error: errors[10],
            locations: [(line: 18, column: 24)],
            message: "Directive \"@onQuery\" may not be used on FRAGMENT_DEFINITION."
        )
        try assertValidationError(
            error: errors[11],
            locations: [(line: 19, column: 10)],
            message: "Directive \"@onQuery\" may not be used on FIELD."
        )
    }

    let schemaWithDirectives = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "Query",
            fields: [
                "dummy": GraphQLField(type: GraphQLString) { inputValue, _, _, _ -> String? in
                    print(type(of: inputValue))
                    return nil
                },
            ]
        ),
        directives: {
            var directives = specifiedDirectives
            directives.append(contentsOf: [
                try! GraphQLDirective(name: "onQuery", locations: [.query]),
                try! GraphQLDirective(name: "onMutation", locations: [.mutation]),
                try! GraphQLDirective(name: "onSubscription", locations: [.subscription]),
                try! GraphQLDirective(name: "onField", locations: [.field]),
                try! GraphQLDirective(
                    name: "onFragmentDefinition",
                    locations: [.fragmentDefinition]
                ),
                try! GraphQLDirective(name: "onFragmentSpread", locations: [.fragmentSpread]),
                try! GraphQLDirective(name: "onInlineFragment", locations: [.inlineFragment]),
                try! GraphQLDirective(
                    name: "onVariableDefinition",
                    locations: [.variableDefinition]
                ),
            ])
            return directives
        }()
    )
}

class KnownDirectivesRuleSDLTests: SDLValidationTestCase {
    override func setUp() {
        rule = KnownDirectivesRule
    }

    func testWithDirectiveDefinedInsideSDL() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @test
            }

            directive @test on FIELD_DEFINITION
            """,
            []
        )
    }

    func testWithStandardDirective() throws {
        try assertValidationErrors(
            """
            type Query {
              foo: String @deprecated
            }
            """,
            []
        )
    }

    func testWithOverriddenStandardDirective() throws {
        try assertValidationErrors(
            """
            schema @deprecated {
              query: Query
            }
            directive @deprecated on SCHEMA
            """,
            []
        )
    }

    func testWithDirectiveDefinedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: String
        }
        """)
        let sdl = """
        directive @test on OBJECT

        extend type Query @test
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    func testWithDirectiveUsedInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        directive @test on OBJECT

        type Query {
          foo: String
        }
        """)
        let sdl = """
        extend type Query @test
        """
        try assertValidationErrors(sdl, schema: schema, [])
    }

    func testWithUnknownDirectiveInSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: String
        }
        """)
        let sdl = """
        extend type Query @unknown
        """
        try assertValidationErrors(
            sdl,
            schema: schema,
            [
                GraphQLError(
                    message: #"Unknown directive "@unknown"."#,
                    locations: [.init(line: 1, column: 19)]
                ),
            ]
        )
    }

    func testWithWellPlacedDirectives() throws {
        try assertValidationErrors(
            """
            type MyObj implements MyInterface @onObject {
              myField(myArg: Int @onArgumentDefinition): String @onFieldDefinition
            }

            extend type MyObj @onObject

            scalar MyScalar @onScalar

            extend scalar MyScalar @onScalar

            interface MyInterface @onInterface {
              myField(myArg: Int @onArgumentDefinition): String @onFieldDefinition
            }

            extend interface MyInterface @onInterface

            union MyUnion @onUnion = MyObj | Other

            extend union MyUnion @onUnion

            enum MyEnum @onEnum {
              MY_VALUE @onEnumValue
            }

            extend enum MyEnum @onEnum

            input MyInput @onInputObject {
              myField: Int @onInputFieldDefinition
            }

            extend input MyInput @onInputObject

            schema @onSchema {
              query: MyQuery
            }

            directive @myDirective(arg:String) on ARGUMENT_DEFINITION
            directive @myDirective2(arg:String @myDirective) on FIELD

            extend schema @onSchema
            """,
            schema: schemaWithSDLDirectives,
            []
        )
    }

    func testWithMisplacedDirectives() throws {
        try assertValidationErrors(
            """
            type MyObj implements MyInterface @onInterface {
              myField(myArg: Int @onInputFieldDefinition): String @onInputFieldDefinition
            }

            scalar MyScalar @onEnum

            interface MyInterface @onObject {
              myField(myArg: Int @onInputFieldDefinition): String @onInputFieldDefinition
            }

            union MyUnion @onEnumValue = MyObj | Other

            enum MyEnum @onScalar {
              MY_VALUE @onUnion
            }

            input MyInput @onEnum {
              myField: Int @onArgumentDefinition
            }

            schema @onObject {
              query: MyQuery
            }

            extend schema @onObject
            """,
            schema: schemaWithSDLDirectives,
            [
                GraphQLError(
                    message: #"Directive "@onInterface" may not be used on OBJECT."#,
                    locations: [.init(line: 1, column: 35)]
                ),
                GraphQLError(
                    message: #"Directive "@onInputFieldDefinition" may not be used on ARGUMENT_DEFINITION."#,
                    locations: [.init(line: 2, column: 22)]
                ),
                GraphQLError(
                    message: #"Directive "@onInputFieldDefinition" may not be used on FIELD_DEFINITION."#,
                    locations: [.init(line: 2, column: 55)]
                ),
                GraphQLError(
                    message: #"Directive "@onEnum" may not be used on SCALAR."#,
                    locations: [.init(line: 5, column: 17)]
                ),
                GraphQLError(
                    message: #"Directive "@onObject" may not be used on INTERFACE."#,
                    locations: [.init(line: 7, column: 23)]
                ),
                GraphQLError(
                    message: #"Directive "@onInputFieldDefinition" may not be used on ARGUMENT_DEFINITION."#,
                    locations: [.init(line: 8, column: 22)]
                ),
                GraphQLError(
                    message: #"Directive "@onInputFieldDefinition" may not be used on FIELD_DEFINITION."#,
                    locations: [.init(line: 8, column: 55)]
                ),
                GraphQLError(
                    message: #"Directive "@onEnumValue" may not be used on UNION."#,
                    locations: [.init(line: 11, column: 15)]
                ),
                GraphQLError(
                    message: #"Directive "@onScalar" may not be used on ENUM."#,
                    locations: [.init(line: 13, column: 13)]
                ),
                GraphQLError(
                    message: #"Directive "@onUnion" may not be used on ENUM_VALUE."#,
                    locations: [.init(line: 14, column: 12)]
                ),
                GraphQLError(
                    message: #"Directive "@onEnum" may not be used on INPUT_OBJECT."#,
                    locations: [.init(line: 17, column: 15)]
                ),
                GraphQLError(
                    message: #"Directive "@onArgumentDefinition" may not be used on INPUT_FIELD_DEFINITION."#,
                    locations: [.init(line: 18, column: 16)]
                ),
                GraphQLError(
                    message: #"Directive "@onObject" may not be used on SCHEMA."#,
                    locations: [.init(line: 21, column: 8)]
                ),
                GraphQLError(
                    message: #"Directive "@onObject" may not be used on SCHEMA."#,
                    locations: [.init(line: 25, column: 15)]
                ),
            ]
        )
    }

    let schemaWithSDLDirectives = try! GraphQLSchema(
        directives: {
            var directives = specifiedDirectives
            directives.append(contentsOf: [
                try! GraphQLDirective(name: "onSchema", locations: [.schema]),
                try! GraphQLDirective(name: "onScalar", locations: [.scalar]),
                try! GraphQLDirective(name: "onObject", locations: [.object]),
                try! GraphQLDirective(name: "onFieldDefinition", locations: [.fieldDefinition]),
                try! GraphQLDirective(
                    name: "onArgumentDefinition",
                    locations:
                    [.argumentDefinition]
                ),
                try! GraphQLDirective(name: "onInterface", locations: [.interface]),
                try! GraphQLDirective(name: "onUnion", locations: [.union]),
                try! GraphQLDirective(name: "onEnum", locations: [.enum]),
                try! GraphQLDirective(name: "onEnumValue", locations: [.enumValue]),
                try! GraphQLDirective(name: "onInputObject", locations: [.inputObject]),
                try! GraphQLDirective(
                    name: "onInputFieldDefinition",
                    locations:
                    [.inputFieldDefinition]
                ),
            ])
            return directives
        }()
    )
}
