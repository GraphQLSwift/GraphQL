import XCTest
import NIO
@testable import GraphQL

class HelloWorldTests : XCTestCase {
    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    resolve: { _, _, _, _ in
                        "world"
                    }
                )
            ]
        )
    )
    
    func testHello() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        let query = "{ hello }"
        let expected = GraphQLResult(data: ["hello": "world"])
        
        let result = try graphql(
            schema: schema,
            request: query,
            eventLoopGroup: group
        ).wait()

        XCTAssertEqual(result, expected)
    }

    func testBoyhowdy() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        let query = "{ boyhowdy }"

        let expected = GraphQLResult(
            errors: [
                GraphQLError(
                    message: "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
                    locations: [SourceLocation(line: 1, column: 3)]
                )
            ]
        )

        let result = try graphql(
            schema: schema,
            request: query,
            eventLoopGroup: group
        ).wait()
        
        XCTAssertEqual(result, expected)
    }
}
