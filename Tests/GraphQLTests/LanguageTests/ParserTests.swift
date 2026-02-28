import Foundation
@testable import GraphQL
import Testing

@Suite struct ParserTests {
    @Test func errorMessages() throws {
        var source: String

        var error = try expectGraphQLError { try parse(source: "{") }
        #expect(
            error.message == """
            Syntax Error GraphQL (1:2) Expected Name, found <EOF>

             1: {
                 ^

            """
        )
        #expect(error.positions == [1])
        #expect(error.locations[0].line == 1)
        #expect(error.locations[0].column == 2)

        error = try expectGraphQLError {
            try parse(source: "{ ...MissingOn }\nfragment MissingOn Type\n")
        }
        #expect(error.message.contains(
            "Syntax Error GraphQL (2:20) Expected \"on\", found Name \"Type\""
        ))

        error = try expectGraphQLError { try parse(source: "{ field: {} }") }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:10) Expected Name, found {"
        ))

        error = try expectGraphQLError {
            try parse(source: "notanoperation Foo { field }")
        }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:1) Unexpected Name \"notanoperation\""
        ))

        error = try expectGraphQLError { try parse(source: "...") }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:1) Unexpected ..."
        ))

        error = try expectGraphQLError {
            try parse(source: Source(
                body: "query",
                name: "MyQuery.graphql"
            ))
        }
        #expect(error.message.contains(
            "Syntax Error MyQuery.graphql (1:6) Expected {, found <EOF>"
        ))

        source = "query Foo($x: Complex = { a: { b: [ $var ] } }) { field }"

        error = try expectGraphQLError { try parse(source: source) }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:37) Unexpected $"
        ))

        error = try expectGraphQLError {
            try parse(source: "fragment on on on { on }")
        }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:10) Unexpected Name \"on\""
        ))

        error = try expectGraphQLError { try parse(source: "{ ...on }") }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:9) Expected Name, found }"
        ))

        error = try expectGraphQLError {
            try parse(
                source: "type WithImplementsButNoTypes implements {}"
            )
        }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:42) Expected Name, found {"
        ))

        error = try expectGraphQLError {
            try parse(source: "type WithImplementsWithTrailingAmp implements AInterface & {}")
        }
        #expect(error.message.contains(
            "Syntax Error GraphQL (1:60) Expected Name, found {"
        ))
    }

    @Test func variableInlineValues() throws {
        _ = try parse(source: "{ field(complex: { a: { b: [ $var ] } }) }")
    }

    @Test func fieldWithArguments() throws {
        let query = """
        {
          stringArgField(stringArg: "Hello World")
          intArgField(intArg: 1)
          floatArgField(floatArg: 3.14)
          falseArgField(boolArg: false)
          trueArgField(boolArg: true)
          nullArgField(value: null)
          enumArgField(enumArg: VALUE)
          multipleArgs(arg1: 1, arg2: false, arg3: THIRD)
        }
        """

        let expected = Document(
            definitions: [
                OperationDefinition(
                    operation: .query,
                    selectionSet: SelectionSet(
                        selections: [
                            Field(
                                name: Name(value: "stringArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "stringArg"),
                                        value: StringValue(value: "Hello World", block: false)
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "intArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "intArg"),
                                        value: IntValue(value: "1")
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "floatArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "floatArg"),
                                        value: FloatValue(value: "3.14")
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "falseArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "boolArg"),
                                        value: BooleanValue(value: false)
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "trueArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "boolArg"),
                                        value: BooleanValue(value: true)
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "nullArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "value"),
                                        value: NullValue()
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "enumArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "enumArg"),
                                        value: EnumValue(value: "VALUE")
                                    ),
                                ]
                            ),
                            Field(
                                name: Name(value: "multipleArgs"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "arg1"),
                                        value: IntValue(value: "1")
                                    ),
                                    Argument(
                                        name: Name(value: "arg2"),
                                        value: BooleanValue(value: false)
                                    ),
                                    Argument(
                                        name: Name(value: "arg3"),
                                        value: EnumValue(value: "THIRD")
                                    ),
                                ]
                            ),
                        ]
                    )
                ),
            ]
        )

        let document = try parse(source: query)
        #expect(document == expected)
    }

//      it('parses multi-byte characters', async () => {
//    // Note: \u0A0A could be naively interpretted as two line-feed chars.
//    expect(
//      parse(`
//        # This comment has a \u0A0A multi-byte character.
//        { field(arg: "Has a \u0A0A multi-byte character.") }
//      `)
//    ).to.containSubset({
//      definitions: [ {
//        selectionSet: {
//          selections: [ {
//            arguments: [ {
//              value: {
//                kind: Kind.STRING,
//                value: 'Has a \u0A0A multi-byte character.'
//              }
//            } ]
//          } ]
//        }
//      } ]
//    });
    //  });

    enum ParserTestsError: Error {
        case couldNotFindKitchenSink
    }

    @Test func kitchenSink() throws {
        guard
            let url = Bundle.module.url(forResource: "kitchen-sink", withExtension: "graphql"),
            let kitchenSink = try? String(contentsOf: url, encoding: .utf8)
        else {
            Issue.record("Could not load kitchen sink")
            return
        }

        _ = try parse(source: kitchenSink)
    }

    @Test func nonKeywordAsName() throws {
        let nonKeywords = [
            "on",
            "fragment",
            "query",
            "mutation",
            "subscription",
            "true",
            "false",
        ]

        for nonKeyword in nonKeywords {
            var fragmentName = nonKeyword
            // You can't define or reference a fragment named `on`.
            if nonKeyword == "on" {
                fragmentName = "a"
            }

            _ = try parse(
                source: "query \(nonKeyword) {" +
                    "... \(fragmentName)" +
                    "... on \(nonKeyword) { field }" +
                    "}" +
                    "fragment \(fragmentName) on Type {" +
                    "\(nonKeyword)(\(nonKeyword): $\(nonKeyword)) @\(nonKeyword)(\(nonKeyword): \(nonKeyword))" +
                    "}"
            )
        }
    }

    @Test func anonymousMutationOperation() throws {
        _ = try parse(
            source: "mutation {" +
                "  mutationField" +
                "}"
        )
    }

    @Test func anonymousSubscriptionOperation() throws {
        _ = try parse(
            source: "subscription {" +
                "  subscriptionField" +
                "}"
        )
    }

    @Test func namedMutationOperation() throws {
        _ = try parse(
            source: "mutation Foo {" +
                "  mutationField" +
                "}"
        )
    }

    @Test func namedSubscriptionOperation() throws {
        _ = try parse(
            source: "subscription Foo {" +
                "  subscriptionField" +
                "}"
        )
    }

    @Test func createAST() throws {
        let query = "{" +
            "  node(id: 4) {" +
            "    id," +
            "    name" +
            "  }" +
            "}"

        let expected = Document(
            definitions: [
                OperationDefinition(
                    operation: .query,
                    selectionSet: SelectionSet(
                        selections: [
                            Field(
                                name: Name(value: "node"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "id"),
                                        value: IntValue(value: "4")
                                    ),
                                ],
                                selectionSet: SelectionSet(
                                    selections: [
                                        Field(name: Name(value: "id")),
                                        Field(name: Name(value: "name")),
                                    ]
                                )
                            ),
                        ]
                    )
                ),
            ]
        )

        #expect(try parse(source: query) == expected)
    }

    @Test func noLocation() throws {
        let result = try parse(source: "{ id }", noLocation: true)
        #expect(result.loc == nil)
    }

    @Test func locationSource() throws {
        let source = Source(body: "{ id }")
        let result = try parse(source: source)
        #expect(result.loc?.source == source)
    }

    @Test func locationTokens() throws {
        let source = Source(body: "{ id }")
        let result = try parse(source: source)
        #expect(result.loc?.startToken.kind == .sof)
        #expect(result.loc?.endToken.kind == .eof)
    }

    @Test func parseValue() throws {
        let source = "[123 \"abc\"]"

        let expected: Value = ListValue(
            values: [
                IntValue(value: "123"),
                StringValue(value: "abc", block: false),
            ]
        )

        #expect(try GraphQL.parseValue(source: source) == expected)
    }

    @Test func parseType() throws {
        var source: String
        var expected: Type

        source = "String"

        expected = NamedType(
            name: Name(value: "String")
        )

        #expect(try GraphQL.parseType(source: source) == expected)

        source = "MyType"

        expected = NamedType(
            name: Name(value: "MyType")
        )

        #expect(try GraphQL.parseType(source: source) == expected)

        source = "[MyType]"

        expected = ListType(
            type: NamedType(
                name: Name(value: "MyType")
            )
        )

        #expect(try GraphQL.parseType(source: source) == expected)

        source = "MyType!"

        expected = NonNullType(
            type: NamedType(
                name: Name(value: "MyType")
            )
        )

        #expect(try GraphQL.parseType(source: source) == expected)

        source = "[MyType!]"

        expected = ListType(
            type: NonNullType(
                type: NamedType(
                    name: Name(value: "MyType")
                )
            )
        )

        #expect(try GraphQL.parseType(source: source) == expected)
    }

    @Test func parseDirective() throws {
        let source = #"""
        directive @restricted(
          """The reason for this restriction"""
          reason: String = null
        ) on FIELD_DEFINITION
        """#

        let expected = Document(definitions: [
            DirectiveDefinition(
                description: nil,
                name: Name(value: "restricted"),
                arguments: [
                    InputValueDefinition(
                        description: StringValue(
                            value: "The reason for this restriction",
                            block: true
                        ),
                        name: Name(value: "reason"),
                        type: NamedType(name: Name(value: "String")),
                        defaultValue: NullValue()
                    ),
                ],
                locations: [
                    Name(value: "FIELD_DEFINITION"),
                ]
            ),
        ])

        let document = try parse(source: source)
        #expect(document == expected)
    }
}

/// This function exists because `error = #require(throwing: GraphQLError) { ... }` doesn't work
/// until Swift 6.1. Once we drop 6.0 support, we can change all calls of this to
/// `error = #require(throwing: GraphQLError) { ... }`
private func expectGraphQLError<T>(_ test: () throws -> T) throws -> GraphQLError {
    do {
        _ = try test()
        Issue.record("Parsing error expected")
        throw ExpectGraphQLError.noErrorThrown
    } catch {
        guard let error = error as? GraphQLError else {
            Issue.record("Unexpected error \(error)")
            throw ExpectGraphQLError.incorrectErrorType(error)
        }
        return error
    }
}

enum ExpectGraphQLError: Error {
    case noErrorThrown
    case incorrectErrorType(Error)
}
