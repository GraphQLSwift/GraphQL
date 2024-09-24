@testable import GraphQL
import NIO
import XCTest

class IntrospectionTests: XCTestCase {
    private var eventLoopGroup: EventLoopGroup!

    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    override func tearDown() {
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }

    func testDefaultValues() throws {
        let numEnum = try GraphQLEnumType(
            name: "Enum",
            values: [
                "One": .init(value: "One"),
                "Two": .init(value: "Two"),
            ]
        )
        let inputObject = try GraphQLInputObjectType(
            name: "InputObject",
            fields: ["str": .init(type: GraphQLString)]
        )
        let outputObject = try GraphQLObjectType(
            name: "Object",
            fields: ["str": .init(type: GraphQLString)]
        )

        let query = try GraphQLObjectType(
            name: "Query",
            fields: [
                "bool": .init(
                    type: GraphQLBoolean,
                    args: [
                        "bool": .init(
                            type: GraphQLBoolean,
                            defaultValue: true
                        ),
                    ]
                ),
                "enum": .init(
                    type: numEnum,
                    args: [
                        "enum": .init(
                            type: numEnum,
                            defaultValue: "One"
                        ),
                    ]
                ),
                "float": .init(
                    type: GraphQLFloat,
                    args: [
                        "float": .init(
                            type: GraphQLFloat,
                            defaultValue: 2.2
                        ),
                    ]
                ),
                "id": .init(
                    type: GraphQLID,
                    args: [
                        "id": .init(
                            type: GraphQLID,
                            defaultValue: "5"
                        ),
                    ]
                ),
                "int": .init(
                    type: GraphQLInt,
                    args: [
                        "int": .init(
                            type: GraphQLInt,
                            defaultValue: 5
                        ),
                    ]
                ),
                "list": .init(
                    type: GraphQLList(GraphQLInt),
                    args: [
                        "list": .init(
                            type: GraphQLList(GraphQLInt),
                            defaultValue: [1, 2, 3]
                        ),
                    ]
                ),
                "object": .init(
                    type: outputObject,
                    args: [
                        "input": .init(
                            type: inputObject,
                            defaultValue: ["str": "hello"]
                        ),
                    ]
                ),
                "string": .init(
                    type: GraphQLString,
                    args: [
                        "string": .init(
                            type: GraphQLString,
                            defaultValue: "hello"
                        ),
                    ]
                ),
            ]
        )

        let schema = try GraphQLSchema(query: query, types: [inputObject, outputObject])

        let introspection = try graphql(
            schema: schema,
            request: """
            query IntrospectionTypeQuery {
              __schema {
                types {
                  fields {
                    args {
                      defaultValue
                      name
                      type {
                        name
                      }
                    }
                    name
                    type {
                      name
                    }
                  }
                  name
                }
              }
            }
            """,
            eventLoopGroup: eventLoopGroup
        ).wait()

        let queryType = try XCTUnwrap(
            introspection.data?["__schema"]["types"].array?
                .find { $0["name"] == "Query" }
        )

        XCTAssertEqual(
            queryType,
            [
                "fields": [
                    [
                        "args": [
                            [
                                "defaultValue": "true",
                                "name": "bool",
                                "type": [
                                    "name": "Boolean",
                                ],
                            ],
                        ],
                        "name": "bool",
                        "type": [
                            "name": "Boolean",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "One",
                                "name": "enum",
                                "type": [
                                    "name": "Enum",
                                ],
                            ],
                        ],
                        "name": "enum",
                        "type": [
                            "name": "Enum",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "2.2",
                                "name": "float",
                                "type": [
                                    "name": "Float",
                                ],
                            ],
                        ],
                        "name": "float",
                        "type": [
                            "name": "Float",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "5",
                                "name": "id",
                                "type": [
                                    "name": "ID",
                                ],
                            ],
                        ],
                        "name": "id",
                        "type": [
                            "name": "ID",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "5",
                                "name": "int",
                                "type": [
                                    "name": "Int",
                                ],
                            ],
                        ],
                        "name": "int",
                        "type": [
                            "name": "Int",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "[1, 2, 3]",
                                "name": "list",
                                "type": [
                                    "name": .null,
                                ],
                            ],
                        ],
                        "name": "list",
                        "type": [
                            "name": .null,
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "{ str: \"hello\" }",
                                "name": "input",
                                "type": [
                                    "name": "InputObject",
                                ],
                            ],
                        ],
                        "name": "object",
                        "type": [
                            "name": "Object",
                        ],
                    ],
                    [
                        "args": [
                            [
                                "defaultValue": "\"hello\"",
                                "name": "string",
                                "type": [
                                    "name": "String",
                                ],
                            ],
                        ],
                        "name": "string",
                        "type": [
                            "name": "String",
                        ],
                    ],
                ],
                "name": "Query",
            ]
        )
    }
}
