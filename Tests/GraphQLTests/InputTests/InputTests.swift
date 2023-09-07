@testable import GraphQL
import NIO
import XCTest

class InputTests: XCTestCase {
    func testArgsNonNullNoDefault() throws {
        struct Echo: Codable {
            let field1: String
        }

        struct EchoArgs: Codable {
            let field1: String
        }

        let EchoOutputType = try GraphQLObjectType(
            name: "Echo",
            description: "",
            fields: [
                "field1": GraphQLField(
                    type: GraphQLNonNull(GraphQLString)
                ),
            ],
            isTypeOf: { source, _, _ in
                source is Echo
            }
        )

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "field1": GraphQLArgument(
                                type: GraphQLNonNull(GraphQLString)
                            ),
                        ],
                        resolve: { _, arguments, _, _ in
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.field1
                            )
                        }
                    ),
                ]
            ),
            types: [EchoOutputType]
        )

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        // Test basic functionality
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: "value1"
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": "value1",
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in an error
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: null
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait()
                .errors.count > 0
        )
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": .null,
                ]
            ).wait()
                .errors.count > 0
        )

        // Test not providing parameter results in an error
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                {
                    echo {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait()
                .errors.count > 0
        )
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait()
                .errors.count > 0
        )
    }

    func testArgsNullNoDefault() throws {
        struct Echo: Codable {
            let field1: String?
        }

        struct EchoArgs: Codable {
            let field1: String?
        }

        let EchoOutputType = try GraphQLObjectType(
            name: "Echo",
            description: "",
            fields: [
                "field1": GraphQLField(
                    type: GraphQLString
                ),
            ],
            isTypeOf: { source, _, _ in
                source is Echo
            }
        )

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "field1": GraphQLArgument(
                                type: GraphQLString
                            ),
                        ],
                        resolve: { _, arguments, _, _ in
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.field1
                            )
                        }
                    ),
                ]
            ),
            types: [EchoOutputType]
        )

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        // Test basic functionality
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: "value1"
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": "value1",
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null is accepted
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: null
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": .null,
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )

        // Test not providing parameter is accepted
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
    }

    func testArgsNonNullDefault() throws {
        struct Echo: Codable {
            let field1: String
        }

        struct EchoArgs: Codable {
            let field1: String
        }

        let EchoOutputType = try GraphQLObjectType(
            name: "Echo",
            description: "",
            fields: [
                "field1": GraphQLField(
                    type: GraphQLNonNull(GraphQLString)
                ),
            ],
            isTypeOf: { source, _, _ in
                source is Echo
            }
        )

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "field1": GraphQLArgument(
                                type: GraphQLNonNull(GraphQLString),
                                defaultValue: .string("defaultValue1")
                            ),
                        ],
                        resolve: { _, arguments, _, _ in
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.field1
                            )
                        }
                    ),
                ]
            ),
            types: [EchoOutputType]
        )

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        // Test basic functionality
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: "value1"
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": "value1",
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in an error
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: null
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait()
                .errors.count > 0
        )
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": .null,
                ]
            ).wait()
                .errors.count > 0
        )

        // Test not providing parameter results in default
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String! = "defaultValue1") {
                    echo (
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )

        // Test variable doesn't get argument default
        XCTAssertTrue(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo (
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait()
                .errors.count > 0
        )
    }

    func testArgsNullDefault() throws {
        struct Echo: Codable {
            let field1: String?
        }

        struct EchoArgs: Codable {
            let field1: String?
        }

        let EchoOutputType = try GraphQLObjectType(
            name: "Echo",
            description: "",
            fields: [
                "field1": GraphQLField(
                    type: GraphQLString
                ),
            ],
            isTypeOf: { source, _, _ in
                source is Echo
            }
        )

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "field1": GraphQLArgument(
                                type: GraphQLString,
                                defaultValue: .string("defaultValue1")
                            ),
                        ],
                        resolve: { _, arguments, _, _ in
                            let args = try MapDecoder().decode(EchoArgs.self, from: arguments)
                            return Echo(
                                field1: args.field1
                            )
                        }
                    ),
                ]
            ),
            types: [EchoOutputType]
        )

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        // Test basic functionality
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: "value1"
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String!) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": "value1",
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in a null output
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(
                        field1: null
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String) {
                    echo(
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "field1": .null,
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )

        // Test not providing parameter results in default
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo {
                        field1
                    }
                }
                """,
                eventLoopGroup: group
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String = "defaultValue1") {
                    echo (
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )

        // Test that nullable unprovided variables are coerced to null
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($field1: String) {
                    echo (
                        field1: $field1
                    ) {
                        field1
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [:]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
    }

    // Test that input objects parse as expected from non-null literals
    func testInputNoNull() throws {
        struct Echo: Codable {
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

        struct EchoArgs: Codable {
            let input: Echo
        }

        let EchoInputType = try GraphQLInputObjectType(
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

        let EchoOutputType = try GraphQLObjectType(
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

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "input": GraphQLArgument(
                                type: EchoInputType
                            ),
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

        // Test in arguments
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
                ],
            ])
        )

        // Test in variables
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($input: EchoInput) {
                    echo(input: $input) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "input": [
                        "field1": "value1",
                        "field2": "value2",
                    ],
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )
    }

    // Test that inputs parse as expected when null literals are present
    func testInputParsingDefinedNull() throws {
        struct Echo: Codable {
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

        struct EchoArgs: Codable {
            let input: Echo
        }

        let EchoInputType = try GraphQLInputObjectType(
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

        let EchoOutputType = try GraphQLObjectType(
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

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "input": GraphQLArgument(
                                type: EchoInputType
                            ),
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

        // Test in arguments
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
                ],
            ])
        )

        // Test in variables
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($input: EchoInput) {
                    echo(input: $input) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "input": [
                        "field1": "value1",
                        "field2": .null,
                    ],
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }

    // Test that input objects parse as expected when there are missing fields with no default
    func testInputParsingUndefined() throws {
        struct Echo: Codable {
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
                XCTAssertFalse(
                    container
                        .contains(
                            .field2
                        )
                ) // Container should not include field2, since it is undefined
                field2 = try container.decodeIfPresent(String.self, forKey: .field2)
            }
        }

        struct EchoArgs: Codable {
            let input: Echo
        }

        let EchoInputType = try GraphQLInputObjectType(
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

        let EchoOutputType = try GraphQLObjectType(
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

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "input": GraphQLArgument(
                                type: EchoInputType
                            ),
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

        // Test in arguments
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
                ],
            ])
        )

        // Test in variables
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($input: EchoInput) {
                    echo(input: $input) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "input": [
                        "field1": "value1",
                    ],
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }

    // Test that input objects parse as expected when there are missing fields with defaults
    func testInputParsingUndefinedWithDefault() throws {
        struct Echo: Codable {
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

        struct EchoArgs: Codable {
            let input: Echo
        }

        let EchoInputType = try GraphQLInputObjectType(
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

        let EchoOutputType = try GraphQLObjectType(
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

        let schema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "echo": GraphQLField(
                        type: EchoOutputType,
                        args: [
                            "input": GraphQLArgument(
                                type: EchoInputType
                            ),
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

        // Undefined with default gets default
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
                ],
            ])
        )
        // Null literal with default gets null
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                {
                    echo(input:{
                        field1: "value1"
                        field2: null
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
                ],
            ])
        )

        // Test in variable
        // Undefined with default gets default
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($input: EchoInput) {
                    echo(input: $input) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "input": [
                        "field1": "value1",
                    ],
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )
        // Null literal with default gets null
        XCTAssertEqual(
            try graphql(
                schema: schema,
                request: """
                query echo($input: EchoInput) {
                    echo(input: $input) {
                        field1
                        field2
                    }
                }
                """,
                eventLoopGroup: group,
                variableValues: [
                    "input": [
                        "field1": "value1",
                        "field2": .null,
                    ],
                ]
            ).wait(),
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }
}
