import XCTest
import NIO
@testable import GraphQL


class InputTests : XCTestCase {
    
    func testInputParsing() throws {
        struct Echo : Codable {
            let field1: String?
            let field2: String?
            
            init(field1: String?, field2: String?) {
                self.field1 = field1
                self.field2 = field2
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                XCTAssertTrue(container.contains(.field1))
                field1 = try container.decodeIfPresent(String.self, forKey: .field1)
                XCTAssertTrue(container.contains(.field2))
                field2 = try container.decodeIfPresent(String.self, forKey: .field2)
            }
        }

        struct EchoArgs : Codable {
            let input: Echo
        }

        let EchoInputType = try! GraphQLInputObjectType(
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

        let EchoOutputType = try! GraphQLObjectType(
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
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.input.field1,
                                field2: args.input.field2
                            )
                        }
                    ),
                ]
            ),
            types: [EchoInputType, EchoOutputType]
        )
        
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
    
    func testInputParsingDefinedNull() throws {
        struct Echo : Codable {
            let field1: String?
            let field2: String?
            
            init(field1: String?, field2: String?) {
                self.field1 = field1
                self.field2 = field2
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                XCTAssertTrue(container.contains(.field1))
                field1 = try container.decodeIfPresent(String.self, forKey: .field1)
                XCTAssertTrue(container.contains(.field2))
                field2 = try container.decodeIfPresent(String.self, forKey: .field2)
            }
        }

        struct EchoArgs : Codable {
            let input: Echo
        }

        let EchoInputType = try! GraphQLInputObjectType(
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

        let EchoOutputType = try! GraphQLObjectType(
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
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.input.field1,
                                field2: args.input.field2
                            )
                        }
                    ),
                ]
            ),
            types: [EchoInputType, EchoOutputType]
        )
        
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
    
    func testInputParsingUndefined() throws {
        struct Echo : Codable {
            let field1: String?
            let field2: String?
            
            init(field1: String?, field2: String?) {
                self.field1 = field1
                self.field2 = field2
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                XCTAssertTrue(container.contains(.field1))
                field1 = try container.decodeIfPresent(String.self, forKey: .field1)
                XCTAssertFalse(container.contains(.field2)) // Container should not include field2, since it is undefined
                field2 = try container.decodeIfPresent(String.self, forKey: .field2)
            }
        }

        struct EchoArgs : Codable {
            let input: Echo
        }

        let EchoInputType = try! GraphQLInputObjectType(
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

        let EchoOutputType = try! GraphQLObjectType(
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
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.input.field1,
                                field2: args.input.field2
                            )
                        }
                    ),
                ]
            ),
            types: [EchoInputType, EchoOutputType]
        )
        
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
    
    func testInputParsingUndefinedWithDefault() throws {
        struct Echo : Codable {
            let field1: String?
            let field2: String?
            
            init(field1: String?, field2: String?) {
                self.field1 = field1
                self.field2 = field2
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                XCTAssertTrue(container.contains(.field1))
                field1 = try container.decodeIfPresent(String.self, forKey: .field1)
                XCTAssertTrue(container.contains(.field2)) // default value should be used
                field2 = try container.decodeIfPresent(String.self, forKey: .field2)
            }
        }

        struct EchoArgs : Codable {
            let input: Echo
        }

        let EchoInputType = try! GraphQLInputObjectType(
            name: "EchoInput",
            fields: [
                "field1": InputObjectField(
                    type: GraphQLString
                ),
                "field2": InputObjectField(
                    type: GraphQLString,
                    defaultValue: .string("value2")
                ),
            ]
        )

        let EchoOutputType = try! GraphQLObjectType(
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
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.input.field1,
                                field2: args.input.field2
                            )
                        }
                    ),
                ]
            ),
            types: [EchoInputType, EchoOutputType]
        )
        
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
                    "field2": "value2",
                ]
            ])
        )
    }
}
