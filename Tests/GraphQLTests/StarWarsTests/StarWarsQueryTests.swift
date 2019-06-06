import XCTest
import NIO

@testable import GraphQL

class StarWarsQueryTests : XCTestCase {    
    func testHeroNameQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query HeroNameQuery {" +
                    "    hero {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "name": "R2-D2",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testHeroNameAndFriendsQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query HeroNameAndFriendsQuery {" +
                    "    hero {" +
                    "        id" +
                    "        name" +
                    "        friends {" +
                    "            name" +
                    "        }" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
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
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testNestedQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

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

        let expected = GraphQLResult(
            data: [
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
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testFetchLukeQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query FetchLukeQuery {" +
                    "    human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "human": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testOptionalVariable() throws{
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query FetchHeroByEpisodeQuery($episode: String) {" +
            "    hero(episode: $episode) {" +
            "        name" +
            "    }" +
            "}"

        var params: [String: Map]
        var expected: GraphQLResult
        var result: GraphQLResult

        // $episode is not required so we can omit and expect this to work and return R2
        params = [:]

        expected = GraphQLResult(
            data: [
                "hero": [
                    "name": "R2-D2",
                ],
            ]
        )

        result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup, variableValues: params).wait()
        XCTAssertEqual(result, expected)

        // or we can pass "EMPIRE" and expect Luke
        params = [
            "episode": "EMPIRE",
        ]

        expected = GraphQLResult(
            data: [
                "hero": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup, variableValues: params).wait()
        XCTAssertEqual(result, expected)
    }

    func testFetchSomeIDQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query FetchSomeIDQuery($someId: String!) {" +
                    "    human(id: $someId) {" +
                    "        name" +
                    "    }" +
                    "}"

        var params: [String: Map]
        var expected: GraphQLResult
        var result: GraphQLResult

        params = [
            "someId": "1000",
        ]

        expected = GraphQLResult(
            data: [
                "human": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup, variableValues: params).wait()
        XCTAssertEqual(result, expected)

        params = [
            "someId": "1002",
        ]

        expected = GraphQLResult(
            data: [
                "human": [
                    "name": "Han Solo",
                ],
            ]
        )

        result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup, variableValues: params).wait()
        XCTAssertEqual(result, expected)


        params = [
            "someId": "not a valid id",
        ]

        expected = GraphQLResult(
            data: [
                "human": nil,
            ]
        )

        result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup, variableValues: params).wait()
        XCTAssertEqual(result, expected)
    }

    func testFetchLukeAliasedQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query FetchLukeAliasedQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "luke": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testFetchLukeAndLeiaAliasedQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query FetchLukeAndLeiaAliasedQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        name" +
                    "    }" +
                    "    leia: human(id: \"1003\") {" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "luke": [
                    "name": "Luke Skywalker",
                ],
                "leia": [
                    "name": "Leia Organa",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testDuplicateFieldsQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

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

        let expected = GraphQLResult(
            data: [
                "luke": [
                    "name": "Luke Skywalker",
                    "homePlanet": "Tatooine",
                ],
                "leia": [
                    "name": "Leia Organa",
                    "homePlanet": "Alderaan",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testUseFragmentQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query UseFragmentQuery {" +
                    "    luke: human(id: \"1000\") {" +
                    "        ...HumanFragment" +
                    "    }" +
                    "    leia: human(id: \"1003\") {" +
                    "        ...HumanFragment" +
                    "    }" +
                    "}" +
                    "fragment HumanFragment on Human {" +
                    "    name" +
                    "    homePlanet" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "luke": [
                    "name": "Luke Skywalker",
                    "homePlanet": "Tatooine",
                ],
                "leia": [
                    "name": "Leia Organa",
                    "homePlanet": "Alderaan",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testCheckTypeOfR2Query() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query CheckTypeOfR2Query {" +
                    "    hero {" +
                    "        __typename" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "__typename": "Droid",
                    "name": "R2-D2",
                ],
            ]
        )

        let result = try graphql(
            schema: StarWarsSchema,
            request: query,
            eventLoopGroup: eventLoopGroup
        ).wait()
        
        XCTAssertEqual(result, expected)
    }

    func testCheckTypeOfLukeQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query CheckTypeOfLukeQuery {" +
                    "    hero(episode: EMPIRE) {" +
                    "        __typename" +
                    "        name" +
                    "    }" +
                    "}"

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "__typename": "Human",
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testSecretBackstoryQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query SecretBackstoryQuery {\n" +
                    "    hero {\n" +
                    "        name\n" +
                    "        secretBackstory\n" +
                    "    }\n" +
                    "}\n"

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "name": "R2-D2",
                    "secretBackstory": nil,
                ],
            ],
            errors: [
                GraphQLError(
                    message: "secretBackstory is secret.",
                    locations: [SourceLocation(line: 4, column: 9)],
                    path: ["hero", "secretBackstory"]
                )
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testSecretBackstoryListQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query SecretBackstoryListQuery {\n" +
                    "    hero {\n" +
                    "        name\n" +
                    "        friends {\n" +
                    "            name\n" +
                    "            secretBackstory\n" +
                    "        }\n" +
                    "    }\n" +
                    "}\n"

        let expected = GraphQLResult(
            data: [
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
            ],
            errors: [
                GraphQLError(
                    message: "secretBackstory is secret.",
                    locations: [SourceLocation(line: 6, column: 13)],
                    path: ["hero", "friends", 0, "secretBackstory"]
                ),
                GraphQLError(
                    message: "secretBackstory is secret.",
                    locations: [SourceLocation(line: 6, column: 13)],
                    path: ["hero", "friends", 1, "secretBackstory"]
                ),
                GraphQLError(
                    message: "secretBackstory is secret.",
                    locations: [SourceLocation(line: 6, column: 13)],
                    path: ["hero", "friends", 2, "secretBackstory"]
                ),
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testSecretBackstoryAliasQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let query = "query SecretBackstoryAliasQuery {\n" +
                    "    mainHero: hero {\n" +
                    "        name\n" +
                    "        story: secretBackstory\n" +
                    "    }\n" +
                    "}\n"

        let expected = GraphQLResult(
            data: [
                "mainHero": [
                    "name": "R2-D2",
                    "story": nil,
                ],
            ],
            errors: [
                GraphQLError(
                    message: "secretBackstory is secret.",
                    locations: [SourceLocation(line: 4, column: 9)],
                    path: ["mainHero", "story"]
                ),
            ]
        )

        let result = try graphql(schema: StarWarsSchema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }

    func testNonNullableFieldsQuery() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
        }

        let A = try GraphQLObjectType(
            name: "A",
            fields: [
                "nullableA": GraphQLField(
                    type: GraphQLTypeReference("A"),
                    resolve: { _, _, _, eventLoopGroup, _ in eventLoopGroup.next().newSucceededFuture(result: [:]) }
                ),
                "nonNullA": GraphQLField(
                    type: GraphQLNonNull(GraphQLTypeReference("A")),
                    resolve: { _, _, _, eventLoopGroup, _ in eventLoopGroup.next().newSucceededFuture(result: [:]) }
                ),
                "throws": GraphQLField(
                    type: GraphQLNonNull(GraphQLString),
                    resolve: { _, _, _, _, _ in
                        struct 🏃 : Error, CustomStringConvertible {
                            let description: String
                        }

                        throw 🏃(description: "catch me if you can.")
                    }
                ),
            ]
        )

        let queryType = try GraphQLObjectType(
            name: "query",
            fields: [
                "nullableA": GraphQLField(
                    type: A,
                    resolve: { _, _, _, eventLoopGroup, _ in eventLoopGroup.next().newSucceededFuture(result: [:]) }
                )
            ]
        )

          let schema = try GraphQLSchema(
            query: queryType
          )

        let query = "query {\n" +
                    "    nullableA {\n" +
                    "        nullableA {\n" +
                    "            nonNullA {\n" +
                    "                nonNullA {\n" +
                    "                    throws\n" +
                    "                }\n" +
                    "            }\n" +
                    "        }\n" +
                    "    }\n" +
                    "}\n"

        let expected = GraphQLResult(
            data: [
                "nullableA": [
                    "nullableA": nil,
                ],
            ],
            errors: [
                GraphQLError(
                    message: "catch me if you can.",
                    locations: [SourceLocation(line: 6, column: 21)],
                    path: ["nullableA", "nullableA", "nonNullA", "nonNullA", "throws"]
                ),
            ]
        )

        let result = try graphql(schema: schema, request: query, eventLoopGroup: eventLoopGroup).wait()
        XCTAssertEqual(result, expected)
    }
}

extension StarWarsQueryTests {
    static var allTests: [(String, (StarWarsQueryTests) -> () throws -> Void)] {
        return [
            ("testHeroNameQuery", testHeroNameQuery),
            ("testHeroNameAndFriendsQuery", testHeroNameAndFriendsQuery),
            ("testNestedQuery", testNestedQuery),
            ("testFetchLukeQuery", testFetchLukeQuery),
            ("testOptionalVariable", testOptionalVariable),
            ("testFetchSomeIDQuery", testFetchSomeIDQuery),
            ("testFetchLukeAliasedQuery", testFetchLukeAliasedQuery),
            ("testFetchLukeAndLeiaAliasedQuery", testFetchLukeAndLeiaAliasedQuery),
            ("testDuplicateFieldsQuery", testDuplicateFieldsQuery),
            ("testUseFragmentQuery", testUseFragmentQuery),
            ("testCheckTypeOfR2Query", testCheckTypeOfR2Query),
            ("testCheckTypeOfLukeQuery", testCheckTypeOfLukeQuery),
            ("testSecretBackstoryQuery", testSecretBackstoryQuery),
            ("testSecretBackstoryListQuery", testSecretBackstoryListQuery),
            ("testSecretBackstoryAliasQuery",testSecretBackstoryAliasQuery),
            ("testNonNullableFieldsQuery", testNonNullableFieldsQuery)
        ]
    }
}
