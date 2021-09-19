import XCTest
import NIO
@testable import GraphQL

fileprivate struct Echo {
    let field1: String?
    let field2: String?
}

fileprivate let EchoInputType = try! GraphQLInputObjectType(
    name: "EchoInput",
    fields: [
        "field1": InputObjectField(
            type: GraphQLString
        ),
        "field2": InputObjectField(
            type: GraphQLString
        ),
    ]
)

fileprivate let EchoOutputType = try! GraphQLObjectType(
    name: "Echo",
    description: "",
    fields: [
        "field1": GraphQLField(
            type: GraphQLString
        ),
        "field2": GraphQLField(
            type: GraphQLString
        ),
    ],
    isTypeOf: { source, _, _ in
        source is Echo
    }
)

class InputTests : XCTestCase {
    
    let schema = try! GraphQLSchema(
        query: try! GraphQLObjectType(
            name: "Query",
            fields: [
                "echo": GraphQLField(
                    type: EchoOutputType,
                    args: [
                        "input": GraphQLArgument(
                            type: EchoInputType
                        )
                    ],
                    resolve: { _, arguments, _, _ in
                        let input = arguments["input"]
                        print(input["field2"])
                        return Echo(
                            field1: input["field1"].string,
                            field2: input["field2"].string
                        )
                    }
                ),
            ]
        ),
        types: [EchoInputType, EchoOutputType]
    )
    
    func testBasic() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }
        
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(input:{
                        field1: "value1",
                        field2: "value2",
                    }) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ]
            ])
        )
    }
    
    func testIncludedNull() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }
        
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(input:{
                        field1: "value1",
                        field2: null,
                    }) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ]
            ])
        )
    }
    
    func testImpliedNull() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }
        
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(input:{
                        field1: "value1"
                    }) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ]
            ])
        )
    }
}
