@testable import GraphQL
import XCTest

class InputTests: XCTestCase {
    func testArgsNonNullNoDefault() async throws {
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
            isTypeOf: { source, _ in
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

        // Test basic functionality
        var result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: "value1"
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": "value1",
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in an error
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: null
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertTrue(
            result.errors.count > 0
        )
        result = try await graphql(
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
            variableValues: [
                "field1": .null,
            ]
        )
        XCTAssertTrue(
            result.errors.count > 0
        )

        // Test not providing parameter results in an error
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo {
                    field1
                }
            }
            """
        )
        XCTAssertTrue(
            result.errors.count > 0
        )
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertTrue(
            result.errors.count > 0
        )
    }

    func testArgsNullNoDefault() async throws {
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
            isTypeOf: { source, _ in
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

        // Test basic functionality
        var result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: "value1"
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": "value1",
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null is accepted
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: null
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": .null,
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )

        // Test not providing parameter is accepted
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
    }

    func testArgsNonNullDefault() async throws {
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
            isTypeOf: { source, _ in
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

        // Test basic functionality
        var result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: "value1"
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": "value1",
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in an error
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: null
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertTrue(
            result.errors.count > 0
        )
        result = try await graphql(
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
            variableValues: [
                "field1": .null,
            ]
        )
        XCTAssertTrue(
            result.errors.count > 0
        )

        // Test not providing parameter results in default
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )

        // Test variable doesn't get argument default
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertTrue(
            result.errors.count > 0
        )
    }

    func testArgsNullDefault() async throws {
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
            isTypeOf: { source, _ in
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

        // Test basic functionality
        var result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: "value1"
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": "value1",
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                ],
            ])
        )

        // Test providing null results in a null output
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo(
                    field1: null
                ) {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [
                "field1": .null,
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )

        // Test not providing parameter results in default
        result = try await graphql(
            schema: schema,
            request: """
            {
                echo {
                    field1
                }
            }
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "defaultValue1",
                ],
            ])
        )

        // Test that nullable unprovided variables are coerced to null
        result = try await graphql(
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
            variableValues: [:]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": .null,
                ],
            ])
        )
    }

    // Test that input objects parse as expected from non-null literals
    func testInputNoNull() async throws {
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
            isTypeOf: { source, _ in
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

        // Test in arguments
        var result = try await graphql(
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
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )

        // Test in variables
        result = try await graphql(
            schema: schema,
            request: """
            query echo($input: EchoInput) {
                echo(input: $input) {
                    field1
                    field2
                }
            }
            """,
            variableValues: [
                "input": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )
    }

    // Test that inputs parse as expected when null literals are present
    func testInputParsingDefinedNull() async throws {
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
            isTypeOf: { source, _ in
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

        // Test in arguments
        var result = try await graphql(
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
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )

        // Test in variables
        result = try await graphql(
            schema: schema,
            request: """
            query echo($input: EchoInput) {
                echo(input: $input) {
                    field1
                    field2
                }
            }
            """,
            variableValues: [
                "input": [
                    "field1": "value1",
                    "field2": .null,
                ],
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }

    // Test that input objects parse as expected when there are missing fields with no default
    func testInputParsingUndefined() async throws {
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
            isTypeOf: { source, _ in
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

        // Test in arguments
        var result = try await graphql(
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
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )

        // Test in variables
        result = try await graphql(
            schema: schema,
            request: """
            query echo($input: EchoInput) {
                echo(input: $input) {
                    field1
                    field2
                }
            }
            """,
            variableValues: [
                "input": [
                    "field1": "value1",
                ],
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }

    // Test that input objects parse as expected when there are missing fields with defaults
    func testInputParsingUndefinedWithDefault() async throws {
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
            isTypeOf: { source, _ in
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

        // Undefined with default gets default
        var result = try await graphql(
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
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )
        // Null literal with default gets null
        result = try await graphql(
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
            """
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )

        // Test in variable
        // Undefined with default gets default
        result = try await graphql(
            schema: schema,
            request: """
            query echo($input: EchoInput) {
                echo(input: $input) {
                    field1
                    field2
                }
            }
            """,
            variableValues: [
                "input": [
                    "field1": "value1",
                ],
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": "value2",
                ],
            ])
        )
        // Null literal with default gets null
        result = try await graphql(
            schema: schema,
            request: """
            query echo($input: EchoInput) {
                echo(input: $input) {
                    field1
                    field2
                }
            }
            """,
            variableValues: [
                "input": [
                    "field1": "value1",
                    "field2": .null,
                ],
            ]
        )
        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "echo": [
                    "field1": "value1",
                    "field2": nil,
                ],
            ])
        )
    }
}
