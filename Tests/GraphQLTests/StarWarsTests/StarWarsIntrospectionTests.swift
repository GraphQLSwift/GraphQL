import XCTest
@testable import GraphQL

class StarWarsIntrospectionTests : XCTestCase {
    func testIntrospectionTypeQuery() throws {
        let query = "query IntrospectionTypeQuery {" +
                    "    __schema {" +
                    "        types {" +
                    "            name {" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__schema": [
                "types": [
                    [
                        "name": "Query",
                    ],
                    [
                        "name": "Episode",
                    ],
                    [
                        "name": "Character",
                    ],
                    [
                        "name": "String",
                    ],
                    [
                        "name": "Human",
                    ],
                    [
                        "name": "Droid",
                    ],
                    [
                        "name": "__Schema",
                    ],
                    [
                        "name": "__Type",
                    ],
                    [
                        "name": "__TypeKind",
                    ],
                    [
                        "name": "Boolean",
                    ],
                    [
                        "name": "__Field",
                    ],
                    [
                        "name": "__InputValue",
                    ],
                    [
                        "name": "__EnumValue",
                    ],
                    [
                        "name": "__Directive",
                    ],
                    [
                        "name": "__DirectiveLocation",
                    ],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionQueryTypeQuery() throws {
        let query = "query IntrospectionQueryTypeQuery {" +
                    "    __schema {" +
                    "        queryType {" +
                    "            name {" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__schema": [
                "queryType": [
                    [
                        "name": "Query",
                    ],

                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionDroidTypeQuery() throws {
        let query = "query IntrospectionDroidTypeQuery {" +
                    "    __type(name: \"Droid\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                [
                    "name": "Droid",
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionDroidKindQuery() throws {
        let query = "query IntrospectionDroidKindQuery {" +
                    "    __type(name: \"Droid\") {" +
                    "        name" +
                    "        kind" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                [
                    "name": "Droid",
                    "kind": "OBJECT",
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionCharacterKindQuery() throws {
        let query = "query IntrospectionCharacterKindQuery {" +
                    "    __type(name: \"Character\") {" +
                    "        name" +
                    "        kind" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                [
                    "name": "Character",
                    "kind": "INTERFACE",
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionDroidFieldsQuery() throws {
        let query = "query IntrospectionDroidFieldsQuery {" +
                    "    __type(name: \"Droid\") {" +
                    "        name" +
                    "        fields {" +
                    "            name" +
                    "            type {" +
                    "                name" +
                    "                kind" +
                    "            }" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                [
                    "name": "Character",
                    "fields": [
                        [
                            "name": "id",
                            "type": [
                                "name": nil,
                                "kind": "NON_NULL",
                            ],
                        ],
                        [
                            "name": "name",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                            ],
                        ],
                        [
                            "name": "friends",
                            "type": [
                                "name": nil,
                                "kind": "LIST",
                            ],
                        ],
                        [
                            "name": "appearsIn",
                            "type": [
                                "name": nil,
                                "kind": "LIST",
                            ],
                        ],
                        [
                            "name": "secretBackstory",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                            ],
                        ],
                        [
                            "name": "primaryFunction",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                            ],
                        ],
                    ],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionDroidNestedFieldsQuery() throws {
        let query = "query IntrospectionDroidNestedFieldsQuery {" +
                    "    __type(name: \"Droid\") {" +
                    "        name" +
                    "        fields {" +
                    "            name" +
                    "            type {" +
                    "                name" +
                    "                kind" +
                    "                ofType {" +
                    "                    name" +
                    "                    kind" +
                    "                }" +
                    "            }" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                [
                    "name": "Character",
                    "fields": [
                        [
                            "name": "id",
                            "type": [
                                "name": nil,
                                "kind": "NON_NULL",
                                "ofType": [
                                    "name": "String",
                                    "kind": "SCALAR",
                                ],
                            ],
                        ],
                        [
                            "name": "name",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                                "ofType": nil,
                            ],
                        ],
                        [
                            "name": "friends",
                            "type": [
                                "name": nil,
                                "kind": "LIST",
                                "ofType": [
                                    "name": "Character",
                                    "kind": "INTERFACE",
                                ],
                            ],
                        ],
                        [
                            "name": "appearsIn",
                            "type": [
                                "name": nil,
                                "kind": "LIST",
                                "ofType": [
                                    "name": "Episode",
                                    "kind": "ENUM",
                                ],
                            ],
                        ],
                        [
                            "name": "secretBackstory",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                                "ofType": nil,
                            ],
                        ],
                        [
                            "name": "primaryFunction",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                                "ofType": nil,
                            ],
                        ],
                    ],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }




    func testIntrospectionFieldArgsQuery() throws {
        let query = "query IntrospectionFieldArgsQuery {" +
                    "    __schema {" +
                    "        queryType {" +
                    "        fields {" +
                    "            name" +
                    "            args {" +
                    "                name" +
                    "                description" +
                    "                type {" +
                    "                    name" +
                    "                    kind" +
                    "                    ofType {" +
                    "                        name" +
                    "                        kind" +
                    "                    }" +
                    "                }" +
                    "                defaultValue" +
                    "            }" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__schema": [
                "queryType": [
                    "fields": [
                        [
                            "name": "hero",
                            "args": [
                                [
                                    "name": "episode",
                                    "description": "If omitted, returns the hero of the whole saga. If provided, returns the hero of that particular episode.",
                                    "type": [
                                        "name": "Episode",
                                        "kind": "ENUM",
                                        "ofType": nil
                                    ],
                                    "defaultValue": nil,
                                ],
                            ],
                        ],
                        [
                            "name": "human",
                            "args": [
                                [
                                    "name": "id",
                                    "description": "id of the human",
                                    "type": [
                                        "name": nil,
                                        "kind": "NON_NULL",
                                        "ofType": [
                                            "name": "String",
                                            "kind": "SCALAR",
                                        ]
                                    ],
                                    "defaultValue": nil,
                                ],
                            ],
                        ],
                        [
                            "name": "droid",
                            "args": [
                                [
                                    "name": "id",
                                    "description": "id of the droid",
                                    "type": [
                                        "name": nil,
                                        "kind": "NON_NULL",
                                        "ofType": [
                                            "name": "String",
                                            "kind": "SCALAR",
                                        ]
                                    ],
                                    "defaultValue": nil,
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testIntrospectionDroidDescriptionQuery() throws {
        let query = "query IntrospectionDroidDescriptionQuery {" +
                    "    __type(name: \"Droid\") {" +
                    "        name" +
                    "        description" +
                    "    }" +
                    "}"

        let expected: Map = [
            "__type": [
                "name": "Droid",
                "description": "A mechanical creature in the Star Wars universe.",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }
}

extension StarWarsIntrospectionTests {
    static var allTests: [(String, (StarWarsIntrospectionTests) -> () throws -> Void)] {
        return [
            ("testIntrospectionTypeQuery", testIntrospectionTypeQuery),
            ("testIntrospectionQueryTypeQuery", testIntrospectionQueryTypeQuery),
            ("testIntrospectionDroidTypeQuery", testIntrospectionDroidTypeQuery),
            ("testIntrospectionDroidKindQuery", testIntrospectionDroidKindQuery),
            ("testIntrospectionCharacterKindQuery", testIntrospectionCharacterKindQuery),
            ("testIntrospectionDroidFieldsQuery", testIntrospectionDroidFieldsQuery),
            ("testIntrospectionDroidNestedFieldsQuery", testIntrospectionDroidNestedFieldsQuery),
            ("testIntrospectionFieldArgsQuery", testIntrospectionFieldArgsQuery),
            ("testIntrospectionDroidDescriptionQuery", testIntrospectionDroidDescriptionQuery),
        ]
    }
}
