import Testing

@testable import GraphQL

@Suite struct StarWarsIntrospectionTests {
    @Test func testIntrospectionTypeQuery() async throws {
        do {
            let query = "query IntrospectionTypeQuery {" +
                "    __schema {" +
                "        types {" +
                "            name" +
                "        }" +
                "    }" +
                "}"

            let expected = GraphQLResult(
                data: [
                    "__schema": [
                        "types": [
                            [
                                "name": "Boolean",
                            ],
                            [
                                "name": "Character",
                            ],
                            [
                                "name": "Droid",
                            ],
                            [
                                "name": "Episode",
                            ],
                            [
                                "name": "Human",
                            ],
                            [
                                "name": "Query",
                            ],
                            [
                                "name": "String",
                            ],
                            [
                                "name": "__Directive",
                            ],
                            [
                                "name": "__DirectiveLocation",
                            ],
                            [
                                "name": "__EnumValue",
                            ],
                            [
                                "name": "__Field",
                            ],
                            [
                                "name": "__InputValue",
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
                        ],
                    ],
                ]
            )

            let result = try await graphql(
                schema: starWarsSchema,
                request: query
            )
            #expect(result == expected)
        } catch {
            print(error)
        }
    }

    @Test func testIntrospectionQueryTypeQuery() async throws {
        let query = "query IntrospectionQueryTypeQuery {" +
            "    __schema {" +
            "        queryType {" +
            "            name" +
            "        }" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__schema": [
                    "queryType": [
                        "name": "Query",
                    ],
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionDroidTypeQuery() async throws {
        let query = "query IntrospectionDroidTypeQuery {" +
            "    __type(name: \"Droid\") {" +
            "        name" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Droid",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionDroidKindQuery() async throws {
        let query = "query IntrospectionDroidKindQuery {" +
            "    __type(name: \"Droid\") {" +
            "        name" +
            "        kind" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Droid",
                    "kind": "OBJECT",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionCharacterKindQuery() async throws {
        let query = "query IntrospectionCharacterKindQuery {" +
            "    __type(name: \"Character\") {" +
            "        name" +
            "        kind" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Character",
                    "kind": "INTERFACE",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionDroidFieldsQuery() async throws {
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

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Droid",
                    "fields": [
                        [
                            "name": "appearsIn",
                            "type": [
                                "name": nil,
                                "kind": "LIST",
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
                            "name": "primaryFunction",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                            ],
                        ],
                        [
                            "name": "secretBackstory",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                            ],
                        ],
                    ],
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionDroidNestedFieldsQuery() async throws {
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

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Droid",
                    "fields": [
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
                            "name": "primaryFunction",
                            "type": [
                                "name": "String",
                                "kind": "SCALAR",
                                "ofType": nil,
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
                    ],
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionFieldArgsQuery() async throws {
        let query = "query IntrospectionFieldArgsQuery {" +
            "    __schema {" +
            "        queryType {" +
            "            fields {" +
            "                name" +
            "                args {" +
            "                    name" +
            "                    description" +
            "                    type {" +
            "                        name" +
            "                        kind" +
            "                        ofType {" +
            "                            name" +
            "                            kind" +
            "                        }" +
            "                    }" +
            "                    defaultValue" +
            "                 }" +
            "            }" +
            "        }" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__schema": [
                    "queryType": [
                        "fields": [
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
                                            ],
                                        ],
                                        "defaultValue": nil,
                                    ],
                                ],
                            ],
                            [
                                "name": "hero",
                                "args": [
                                    [
                                        "name": "episode",
                                        "description": "If omitted, returns the hero of the whole saga. If provided, returns the hero of that particular episode.",
                                        "type": [
                                            "name": "Episode",
                                            "kind": "ENUM",
                                            "ofType": nil,
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
                                            ],
                                        ],
                                        "defaultValue": nil,
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func testIntrospectionDroidDescriptionQuery() async throws {
        let query = "query IntrospectionDroidDescriptionQuery {" +
            "    __type(name: \"Droid\") {" +
            "        name" +
            "        description" +
            "    }" +
            "}"

        let expected = GraphQLResult(
            data: [
                "__type": [
                    "name": "Droid",
                    "description": "A mechanical creature in the Star Wars universe.",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }
}
