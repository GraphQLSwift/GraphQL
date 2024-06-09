@testable import GraphQL
import NIO
import XCTest

class OneOfTests: XCTestCase {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    // MARK: OneOf Input Objects

    func testAcceptsAGoodDefaultValue() throws {
        let query = """
        query ($input: TestInputObject! = {a: "abc"}) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup
        ).wait()
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    func testRejectsABadDefaultValue() throws {
        let query = """
        query ($input: TestInputObject! = {a: "abc", b: 123}) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup
        ).wait()
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(
            result.errors[0].message,
            "OneOf Input Object \"TestInputObject\" must specify exactly one key."
        )
    }

    func testAcceptsAGoodVariable() throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup,
            variableValues: ["input": ["a": "abc"]]
        ).wait()
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    func testAcceptsAGoodVariableWithAnUndefinedKey() throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup,
            variableValues: ["input": ["a": "abc", "b": .undefined]]
        ).wait()
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "test": [
                    "a": "abc",
                    "b": .null,
                ],
            ])
        )
    }

    func testRejectsAVariableWithMultipleNonNullKeys() throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup,
            variableValues: ["input": ["a": "abc", "b": 123]]
        ).wait()
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(
            result.errors[0].message,
            """
            Variable "$input" got invalid value "{"a":"abc","b":123}".
            Exactly one key must be specified for OneOf type "TestInputObject".
            """
        )
    }

    func testRejectsAVariableWithMultipleNullableKeys() throws {
        let query = """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
        """
        let result = try graphql(
            schema: getSchema(),
            request: query,
            eventLoopGroup: eventLoopGroup,
            variableValues: ["input": ["a": "abc", "b": .null]]
        ).wait()
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(
            result.errors[0].message,
            """
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
        isTypeOf: { source, _, _ in
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
