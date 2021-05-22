import XCTest
@testable import GraphQL

class ParserTests : XCTestCase {
    func testErrorMessages() throws {
        var source: String

        XCTAssertThrowsError(try parse(source: "{")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssertEqual(error.message,
                "Syntax Error GraphQL (1:2) Expected Name, found <EOF>\n\n" +
                " 1: {\n" +
                "     ^\n"
            )

            XCTAssertEqual(error.positions, [1])
            XCTAssertEqual(error.locations[0].line, 1)
            XCTAssertEqual(error.locations[0].column, 2)
        }

        XCTAssertThrowsError(try parse(source: "{ ...MissingOn }\nfragment MissingOn Type\n")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (2:20) Expected \"on\", found Name \"Type\""
            ))
        }

        XCTAssertThrowsError(try parse(source: "{ field: {} }")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:10) Expected Name, found {"
            ))
        }

        XCTAssertThrowsError(try parse(source: "notanoperation Foo { field }")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:1) Unexpected Name \"notanoperation\""
            ))
        }

        XCTAssertThrowsError(try parse(source: "...")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:1) Unexpected ..."
            ))
        }

        XCTAssertThrowsError(try parse(source: Source(body: "query", name: "MyQuery.graphql"))) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error MyQuery.graphql (1:6) Expected {, found <EOF>"
            ))
        }

        source = "query Foo($x: Complex = { a: { b: [ $var ] } }) { field }"

        XCTAssertThrowsError(try parse(source: source)) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:37) Unexpected $"
            ))
        }

        XCTAssertThrowsError(try parse(source: "fragment on on on { on }")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:10) Unexpected Name \"on\""
            ))
        }

        XCTAssertThrowsError(try parse(source: "{ ...on }")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:9) Expected Name, found }"
            ))
        }

    }

    func testVariableInlineValues() throws {
        _ = try parse(source: "{ field(complex: { a: { b: [ $var ] } }) }")
    }

    func testFieldWithArguments() throws {
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
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "intArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "intArg"),
                                        value: IntValue(value: "1")
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "floatArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "floatArg"),
                                        value: FloatValue(value: "3.14")
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "falseArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "boolArg"),
                                        value: BooleanValue(value: false)
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "trueArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "boolArg"),
                                        value: BooleanValue(value: true)
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "nullArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "value"),
                                        value: NullValue()
                                    )
                                ]
                            ),
                            Field(
                                name: Name(value: "enumArgField"),
                                arguments: [
                                    Argument(
                                        name: Name(value: "enumArg"),
                                        value: EnumValue(value: "VALUE")
                                    )
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
                )
            ]
        )

        let document = try parse(source: query)
        XCTAssert(document == expected)
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

    func testKitchenSink() throws {
//        let path = "/Users/paulofaria/Development/Zewo/GraphQL/Tests/GraphQLTests/LanguageTests/kitchen-sink.graphql"
//        let kitchenSink = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
//        _ = try parse(source: kitchenSink as String)
    }

    func testNonKeywordAsName() throws {
        let nonKeywords = [
            "on",
            "fragment",
            "query",
            "mutation",
            "subscription",
            "true",
            "false"
        ]

        for nonKeyword in nonKeywords {
            var fragmentName = nonKeyword
            // You can't define or reference a fragment named `on`.
            if nonKeyword == "on" {
                fragmentName = "a"
            }

            _ = try parse(source: "query \(nonKeyword) {" +
                                  "... \(fragmentName)" +
                                  "... on \(nonKeyword) { field }" +
                                  "}" +
                                  "fragment \(fragmentName) on Type {" +
                                  "\(nonKeyword)(\(nonKeyword): $\(nonKeyword)) @\(nonKeyword)(\(nonKeyword): \(nonKeyword))" +
                                  "}"
            )
        }
    }

    func testAnonymousMutationOperation() throws {
        _ = try parse(source: "mutation {" +
                              "  mutationField" +
                              "}"
        )
    }

    func testAnonymousSubscriptionOperation() throws {
        _ = try parse(source: "subscription {" +
                              "  subscriptionField" +
                              "}"
        )
    }

    func testNamedMutationOperation() throws {
        _ = try parse(source: "mutation Foo {" +
                              "  mutationField" +
                              "}"
        )
    }

    func testNamedSubscriptionOperation() throws {
        _ = try parse(source: "subscription Foo {" +
                              "  subscriptionField" +
                              "}"
        )
    }

    func testCreateAST() throws {
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
                                    )
                                ],
                                selectionSet: SelectionSet(
                                    selections: [
                                        Field(name: Name(value: "id")),
                                        Field(name: Name(value: "name"))
                                    ]
                                )
                            )
                        ]
                    )
                )
            ]
        )

        XCTAssert(try parse(source: query) == expected)
    }

    func testNoLocation() throws {
        let result = try parse(source: "{ id }", noLocation: true)
        XCTAssertNil(result.loc)
    }

    func testLocationSource() throws {
        let source = Source(body: "{ id }")
        let result = try parse(source: source)
        XCTAssertEqual(result.loc?.source, source)
    }

    func testLocationTokens() throws {
        let source = Source(body: "{ id }")
        let result = try parse(source: source)
        XCTAssertEqual(result.loc?.startToken.kind, .sof)
        XCTAssertEqual(result.loc?.endToken.kind, .eof)
    }

    func testParseValue() throws {
        let source = "[123 \"abc\"]"

        let expected: Value = ListValue(
            values: [
                IntValue(value: "123"),
                StringValue(value: "abc", block: false)
            ]
        )

        XCTAssert(try parseValue(source: source) == expected)
    }

    func testParseType() throws {
        var source: String
        var expected: Type

        source = "String"

        expected = NamedType(
            name: Name(value: "String")
        )

        XCTAssert(try parseType(source: source) == expected)

        source = "MyType"

        expected = NamedType(
            name: Name(value: "MyType")
        )

        XCTAssert(try parseType(source: source) == expected)

        source = "[MyType]"

        expected = ListType(
            type: NamedType(
                name: Name(value: "MyType")
            )
        )

        XCTAssert(try parseType(source: source) == expected)

        source = "MyType!"

        expected = NonNullType(
            type: NamedType(
                name: Name(value: "MyType")
            )
        )

        XCTAssert(try parseType(source: source) == expected)

        source = "[MyType!]"

        expected = ListType(
            type: NonNullType(
                type: NamedType(
                    name: Name(value: "MyType")
                )
            )
        )

        XCTAssert(try parseType(source: source) == expected)
    }

    func testParseDirective() throws {
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
                        description: StringValue(value: "The reason for this restriction", block: true),
                        name: Name(value: "reason"),
                        type: NamedType(name: Name(value: "String")),
                        defaultValue: NullValue()
                    )
                ],
                locations: [
                    Name(value: "FIELD_DEFINITION")
                ]
            )
        ])

        let document = try parse(source: source)
        XCTAssert(document == expected)
    }
}
