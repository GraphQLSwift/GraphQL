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
                    resolve: { _, _, _, eventLoopGroup, _ in return eventLoopGroup.next().newSucceededFuture(result: "world") }
                )
            ]
        )
    )

    func testHello() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "{ hello }"
        let expected: Map = [
            "data": [
                "hello": "world"
            ]
        ]
        let result = try graphql(schema: schema, request: query, eventLoopGroup: eventLoopGroup).wait()

        XCTAssertEqual(result, expected)
    }

    func testBoyhowdy() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "{ boyhowdy }"

        let expectedErrors: Map = [
            "errors": [
                [
                    "message": "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
                    "locations": [["line": 1, "column": 3]]
                ]
            ]
        ]

        let result = try graphql(schema: schema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expectedErrors)
    }
}

extension HelloWorldTests {
    static var allTests: [(String, (HelloWorldTests) -> () throws -> Void)] {
        return [
            ("testHello", testHello),
            ("testBoyhowdy", testBoyhowdy),
        ]
    }
}
