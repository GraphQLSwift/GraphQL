import XCTest
@testable import GraphQL

class GraphQLTests: XCTestCase {
    func testHello() throws {
        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "RootQueryType",
                fields: [
                    "hello": GraphQLFieldConfig(
                        type: GraphQLString,
                        resolve: { _ in "world" }
                    )
                ]
            )
        )

        let query = "{ hello }"

        let result = try graphql(schema: schema, request: query)

        print(result)
    }

    func testBoyhowdy() throws {
        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "RootQueryType",
                fields: [
                    "hello": GraphQLFieldConfig(
                        type: GraphQLString,
                        resolve: { _ in "world" }
                    )
                ]
            )
        )

        let query = "{ boyhowdy }"

        let result = try graphql(schema: schema, request: query)

        print(result)
    }
}

extension GraphQLTests {
    static var allTests: [(String, (GraphQLTests) -> () throws -> Void)] {
        return [
            ("testHello", testHello),
            ("testBoyhowdy", testBoyhowdy),
        ]
    }
}
