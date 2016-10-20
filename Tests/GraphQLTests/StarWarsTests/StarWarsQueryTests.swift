import XCTest
@testable import GraphQL

class StarWarsQueryTests : XCTestCase {    
    func testHeroNameQuery() throws {
        let query = "query HeroNameQuery {" +
                    "    hero {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "name": "R2-D2",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testHeroNameAndFriendsQuery() throws {
        let query = "query HeroNameAndFriendsQuery {" +
                    "    hero {" +
                    "        id" +
                    "        name" +
                    "        friends {" +
                    "            name" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "id": "2001",
                "name": "R2-D2",
                "friends": [
                    ["name": "Luke Skywalker"],
                    ["name": "Han Solo"],
                    ["name": "Leia Organa"],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testNestedQuery() throws {
        let query = "query NestedQuery {" +
                    "    hero {" +
                    "        name" +
                    "        friends {" +
                    "            name" +
                    "            appearsIn" +
                    "            friends {" +
                    "                name" +
                    "            }" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "name": "R2-D2",
                "friends": [
                    [
                        "name": "Luke Skywalker",
                        "appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
                        "friends": [
                            ["name": "Han Solo"],
                            ["name": "Leia Organa"],
                            ["name": "C-3PO"],
                            ["name": "R2-D2"],
                        ],
                    ],
                    [
                        "name": "Han Solo",
                        "appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
                        "friends": [
                            ["name": "Luke Skywalker"],
                            ["name": "Leia Organa"],
                            ["name": "R2-D2"],
                        ],
                    ],
                    [
                        "name": "Leia Organa",
                        "appearsIn": ["NEWHOPE", "EMPIRE", "JEDI"],
                        "friends": [
                            ["name": "Luke Skywalker"],
                            ["name": "Han Solo"],
                            ["name": "C-3PO"],
                            ["name": "R2-D2"],
                        ],
                    ],
                ],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testFetchLukeQuery() throws {
        let query = "query FetchLukeQuery {" +
                    "    human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "human": [
                "name": "Luke Skywalker",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testFetchSomeIDQuery() throws {
        let query = "query FetchSomeIDQuery($someId: String!) {" +
                    "    human(id: $someId) {" +
                    "        name" +
                    "    }" +
                    "}"

        var params: [String: Map] = [
            "someId": "1000",
        ]

        var expected: Map = [
            "human": [
                "name": "Luke Skywalker",
            ],
        ]

        var result = try graphql(schema: StarWarsSchema, request: query, variableValues: params)
        XCTAssertEqual(result["data"], expected)

        params = [
            "someId": "1002",
        ]

        expected = [
            "human": [
                "name": "Han Solo",
            ],
        ]

        result = try graphql(schema: StarWarsSchema, request: query, variableValues: params)
        XCTAssertEqual(result["data"], expected)


        params = [
            "someId": "not a valid id",
        ]

        expected = [
            "human": nil,
        ]

        result = try graphql(schema: StarWarsSchema, request: query, variableValues: params)
        XCTAssertEqual(result["data"], expected)
    }

    func testFetchLukeAliasedQuery() throws {
        let query = "query FetchLukeAliasedQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "luke": [
                "name": "Luke Skywalker",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testFetchLukeAndLeiaAliasedQuery() throws {
        let query = "query FetchLukeAndLeiaAliasedQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "    leia: human(id: \"1003\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "luke": [
                "name": "Luke Skywalker",
            ],
            "leia": [
                "name": "Leia Organa",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testDuplicateFieldsQuery() throws {
        let query = "query DuplicateFieldsQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        name" +
                    "        homePlanet" +
                    "    }" +
                    "    leia: human(id: \"1003\") {" +
                    "        name" +
                    "        homePlanet" +
                    "    }" +
                    "}"

        let expected: Map = [
            "luke": [
                "name": "Luke Skywalker",
                "homePlanet": "Tatooine",
            ],
            "leia": [
                "name": "Leia Organa",
                "homePlanet": "Alderaan",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testUseFragmentQuery() throws {
        let query = "query UseFragmentQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        ...HumanFragment" +
                    "    }" +
                    "    leia: human(id: \"1003\") {" +
                    "        ...HumanFragment" +
                    "    }" +
                    "    fragment HumanFragment on Human {" +
                    "        name" +
                    "        homePlanet" +
                    "    }" +
                    "}"

        let expected: Map = [
            "luke": [
                "name": "Luke Skywalker",
                "homePlanet": "Tatooine",
            ],
            "leia": [
                "name": "Leia Organa",
                "homePlanet": "Alderaan",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testCheckTypeOfR2Query() throws {
        let query = "query CheckTypeOfR2Query {" +
                    "    hero {" +
                    "        __typename" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "__typename": "Droid",
                "name": "R2-D2",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testCheckTypeOfLukeQuery() throws {
        let query = "query CheckTypeOfLukeQuery {" +
                    "    hero(episode: EMPIRE) {" +
                    "        __typename" +
                    "        name" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "__typename": "Human",
                "name": "Luke Skywalker",
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }

    func testSecretBackstoryQuery() throws {
        let query = "query SecretBackstoryQuery {" +
                    "    hero {" +
                    "        name" +
                    "        secretBackstory" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "name": "R2-D2",
                "secretBackstory": nil,
            ],
        ]

        let expectedErrors: Map = [
            [
                "message": "secretBackstory is secret.",
                "path": ["hero", "secretBackstory"],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
        XCTAssertEqual(result["errors"], expectedErrors)
    }

    func testSecretBackstoryListQuery() throws {
        let query = "query SecretBackstoryListQuery {" +
                    "    hero {" +
                    "        name" +
                    "        friends {" +
                    "            name" +
                    "            secretBackstory" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "hero": [
                "name": "R2-D2",
                "friends": [
                    [
                        "name": "Luke Skywalker",
                        "secretBackstory": nil,
                    ],
                    [
                        "name": "Han Solo",
                        "secretBackstory": nil,
                    ],
                    [
                        "name": "Leia Organa",
                        "secretBackstory": nil,
                    ],
                ],
            ],
        ]

        let expectedErrors: Map = [
            [
                "message": "secretBackstory is secret.",
                "path": ["hero", "friends", "0", "secretBackstory"],
            ],
            [
                "message": "secretBackstory is secret.",
                "path": ["hero", "friends", "1", "secretBackstory"],
            ],
            [
                "message": "secretBackstory is secret.",
                "path": ["hero", "friends", "2", "secretBackstory"],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
        XCTAssertEqual(result["errors"], expectedErrors)
    }

    func testSecretBackstoryAliasQuery() throws {
        let query = "query SecretBackstoryAliasQuery {" +
                    "    mainHero: hero {" +
                    "        name" +
                    "        story: secretBackstory" +
                    "    }" +
                    "}"

        let expected: Map = [
            "mainHero": [
                "name": "R2-D2",
                "story": nil,
            ],
        ]

        let expectedErrors: Map = [
            [
                "message": "secretBackstory is secret.",
                "path": ["mainHero", "story"],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
        XCTAssertEqual(result["errors"], expectedErrors)
    }

    func testNonNullableFieldsQuery() throws {
        let A = try GraphQLObjectType(
            name: "A",
            fields: [
                "nullableA": GraphQLFieldConfig(
                    type: GraphQLTypeReference("A"),
                    resolve: { _ in [:] }
                ),
                "nonNullA": GraphQLFieldConfig(
                    type: GraphQLNonNull(GraphQLTypeReference("A")),
                    resolve: { _ in [:] }
                ),
                "throws": GraphQLFieldConfig(
                    type: GraphQLNonNull(GraphQLString),
                    resolve: { _ in
                        struct 🏃 : Error, CustomStringConvertible {
                            let description: String
                        }

                        throw 🏃(description: "catch me if you can")
                    }
                ),
            ]
        )

        let queryType = try GraphQLObjectType(
            name: "query",
            fields: [
                "nullableA": GraphQLFieldConfig(
                    type: A,
                    resolve: { _ in [:] }
                )
            ]
        )

          let schema = try GraphQLSchema(
            query: queryType
          )

        let query = "query {" +
                    "    nullableA {" +
                    "        nullableA {" +
                    "            nonNullA {" +
                    "                nonNullA {" +
                    "                    throws" +
                    "                }" +
                    "            }" +
                    "        }" +
                    "    }" +
                    "}"

        let expected: Map = [
            "nullableA": [
                "nullableA": nil,
            ],
        ]

        let expectedErrors: Map = [
            [
                "message": "secretBackstory is secret.",
                "path": ["nullableA", "nullableA", "nonNullA", "nonNullA", "throws"],
            ],
        ]

        let result = try graphql(schema: StarWarsSchema, request: query)
        XCTAssertEqual(result["data"], expected)
    }
}

extension StarWarsQueryTests {
    static var allTests: [(String, (StarWarsQueryTests) -> () throws -> Void)] {
        return [
            ("testHeroNameQuery", testHeroNameQuery),
            ("testHeroNameAndFriendsQuery", testHeroNameAndFriendsQuery),
            ("testNestedQuery", testNestedQuery),
            ("testFetchLukeQuery", testFetchLukeQuery),
            ("testFetchSomeIDQuery", testFetchSomeIDQuery),
            ("testFetchLukeAliasedQuery", testFetchLukeAliasedQuery),
            ("testFetchLukeAndLeiaAliasedQuery", testFetchLukeAndLeiaAliasedQuery),
            ("testDuplicateFieldsQuery", testDuplicateFieldsQuery),
            ("testUseFragmentQuery", testUseFragmentQuery),
            ("testCheckTypeOfR2Query", testCheckTypeOfR2Query),
            ("testCheckTypeOfLukeQuery", testCheckTypeOfLukeQuery),
            ("testSecretBackstoryQuery", testSecretBackstoryQuery),
            ("testSecretBackstoryListQuery", testSecretBackstoryListQuery),
            ("testNonNullableFieldsQuery", testNonNullableFieldsQuery),
        ]
    }
}
