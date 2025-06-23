@testable import GraphQL
import XCTest

class HelloWorldTests: XCTestCase {
    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    resolve: { _, _, _, _ in
                        "world"
                    }
                ),
            ]
        )
    )

    func testHello() async throws {
        let query = "{ hello }"
        let expected = GraphQLResult(data: ["hello": "world"])

        let result = try await graphql(
            schema: schema,
            request: query
        )

        XCTAssertEqual(result, expected)
    }

    func testBoyhowdy() async throws {
        let query = "{ boyhowdy }"

        let expected = GraphQLResult(
            errors: [
                GraphQLError(
                    message: "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
                    locations: [SourceLocation(line: 1, column: 3)]
                ),
            ]
        )

        let result = try await graphql(
            schema: schema,
            request: query
        )

        XCTAssertEqual(result, expected)
    }

    @available(macOS 10.15, iOS 15, watchOS 8, tvOS 15, *)
    func testHelloAsync() async throws {
        let query = "{ hello }"
        let expected = GraphQLResult(data: ["hello": "world"])

        let result = try await graphql(
            schema: schema,
            request: query
        )

        XCTAssertEqual(result, expected)
    }
}
