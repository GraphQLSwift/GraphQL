@testable import GraphQL
import Testing

@Suite struct OneOfTests {
    // MARK: OneOf Input Objects

    @Test func testAcceptsAGoodDefaultValue() async throws {
        let query = """
        query ($input: TestInputObject! = {a: "abc"}) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query
        )
        #expect(
            result == GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    @Test func testRejectsABadDefaultValue() async throws {
        let query = """
        query ($input: TestInputObject! = {a: "abc", b: 123}) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query
        )
        #expect(result.errors.count == 1)
        #expect(
            result.errors[0].message ==
                "OneOf Input Object \"TestInputObject\" must specify exactly one key."
        )
    }

    @Test func testAcceptsAGoodVariable() async throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query,
            variableValues: ["input": ["a": "abc"]]
        )
        #expect(
            result == GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    @Test func testAcceptsAGoodVariableWithAnUndefinedKey() async throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query,
            variableValues: ["input": ["a": "abc", "b": .undefined]]
        )
        #expect(
            result == GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    @Test func testRejectsAVariableWithMultipleNonNullKeys() async throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query,
            variableValues: ["input": ["a": "abc", "b": 123]]
        )
        #expect(result.errors.count == 1)
        #expect(
            result.errors[0].message == """
            Variable "$input" got invalid value "{"a":"abc","b":123}".
            Exactly one key must be specified for OneOf type "TestInputObject".
            """
        )
    }

    @Test func testRejectsAVariableWithMultipleNullableKeys() async throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try await graphql(
            schema: getSchema(),
            request: query,
            variableValues: ["input": ["a": "abc", "b": .null]]
        )
        #expect(result.errors.count == 1)
        #expect(
            result.errors[0].message == """
            Variable "$input" got invalid value "{"a":"abc","b":null}".
            Exactly one key must be specified for OneOf type "TestInputObject".
            """
        )
    }
}

func getSchema() throws -> GraphQLSchema {
    let testObject = try GraphQLObjectType(
        name: "TestObject",
        fields: [
            "a": GraphQLField(type: GraphQLString),
            "b": GraphQLField(type: GraphQLInt),
        ],
        isTypeOf: { source, _ in
            source is TestObject
        }
    )
    let testInputObject = try GraphQLInputObjectType(
        name: "TestInputObject",
        fields: [
            "a": InputObjectField(type: GraphQLString),
            "b": InputObjectField(type: GraphQLInt),
        ],
        isOneOf: true
    )
    let schema = try GraphQLSchema(
        query: GraphQLObjectType(
            name: "Query",
            fields: [
                "test": GraphQLField(
                    type: testObject,
                    args: [
                        "input": GraphQLArgument(type: GraphQLNonNull(testInputObject)),
                    ],
                    resolve: { _, args, _, _ in
                        try MapDecoder().decode(TestObject.self, from: args["input"])
                    }
                ),
            ]
        ),
        types: [
            testObject,
            testInputObject,
        ]
    )
    return schema
}

struct TestObject: Codable {
    let a: String?
    let b: Int?
}
