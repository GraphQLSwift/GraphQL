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

        XCTAssertThrowsError(try parse(source: "{ fieldWithNullableStringInput(input: null) }")) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }

            XCTAssert(error.message.contains(
                "Syntax Error GraphQL (1:39) Unexpected Name \"null\""
            ))
        }
    }

    func testVariableInlineValues() throws {
        _ = try parse(source: "{ field(complex: { a: { b: [ $var ] } }) }")
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
                StringValue(value: "abc")
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
}

extension ParserTests {
    static var allTests: [(String, (ParserTests) -> () throws -> Void)] {
        return [
            ("testErrorMessages", testErrorMessages),
            ("testVariableInlineValues", testVariableInlineValues),
            ("testKitchenSink", testKitchenSink),
            ("testNonKeywordAsName", testNonKeywordAsName),
            ("testAnonymousMutationOperation", testAnonymousMutationOperation),
            ("testAnonymousSubscriptionOperation", testAnonymousSubscriptionOperation),
            ("testNamedMutationOperation", testNamedMutationOperation),
            ("testNamedSubscriptionOperation", testNamedSubscriptionOperation),
            ("testCreateAST", testCreateAST),
            ("testNoLocation", testNoLocation),
            ("testLocationSource", testLocationSource),
            ("testLocationTokens", testLocationTokens),
            ("testParseValue", testParseValue),
            ("testParseType", testParseType),
        ]
    }
}
