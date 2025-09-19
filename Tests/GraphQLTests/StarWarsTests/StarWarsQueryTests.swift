import Testing

@testable import GraphQL

@Suite struct StarWarsQueryTests {
    @Test func heroNameQuery() async throws {
        let query = """
        query HeroNameQuery {
            hero {
                name
            }
        }
        """

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "name": "R2-D2",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )

        #expect(result == expected)
    }

    @Test func heroNameAndFriendsQuery() async throws {
        let query = """
        query HeroNameAndFriendsQuery {
            hero {
                id
                name
                friends {
                    name
                }
            }
        }
        """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )

        #expect(result == expected)
    }

    @Test func nestedQuery() async throws {
        let query = """
        query NestedQuery {
            hero {
                name
                friends {
                    name
                    appearsIn
                    friends {
                        name
                    }
                }
            }
        }
        """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func fetchLukeQuery() async throws {
        let query =
            """
            query FetchLukeQuery {
                human(id: "1000") {
                    name
                }
            }
            """

        let expected = GraphQLResult(
            data: [
                "human": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func optionalVariable() async throws {
        let query =
            """
            query FetchHeroByEpisodeQuery($episode: Episode) {
                hero(episode: $episode) {
                    name
                }
            }
            """

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

        result = try await graphql(
            schema: starWarsSchema,
            request: query,
            variableValues: params
        )
        #expect(result == expected)

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

        result = try await graphql(
            schema: starWarsSchema,
            request: query,
            variableValues: params
        )
        #expect(result == expected)
    }

    @Test func fetchSomeIDQuery() async throws {
        let query =
            """
            query FetchSomeIDQuery($someId: String!) {
                human(id: $someId) {
                    name
                }
            }
            """

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

        result = try await graphql(
            schema: starWarsSchema,
            request: query,
            variableValues: params
        )
        #expect(result == expected)

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

        result = try await graphql(
            schema: starWarsSchema,
            request: query,
            variableValues: params
        )
        #expect(result == expected)

        params = [
            "someId": "not a valid id",
        ]

        expected = GraphQLResult(
            data: [
                "human": nil,
            ]
        )

        result = try await graphql(
            schema: starWarsSchema,
            request: query,
            variableValues: params
        )
        #expect(result == expected)
    }

    @Test func fetchLukeAliasedQuery() async throws {
        let query =
            """
            query FetchLukeAliasedQuery {
                luke: human(id: "1000") {
                    name
                }
            }
            """

        let expected = GraphQLResult(
            data: [
                "luke": [
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func fetchLukeAndLeiaAliasedQuery() async throws {
        let query =
            """
            query FetchLukeAndLeiaAliasedQuery {
                luke: human(id: "1000") {
                    name
                }
                leia: human(id: "1003") {
                    name
                }
            }
            """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func duplicateFieldsQuery() async throws {
        let query =
            """
            query DuplicateFieldsQuery {
                luke: human(id: "1000") {
                    name
                    homePlanet
                }
                leia: human(id: "1003") {
                    name
                    homePlanet
                }
            }
            """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func useFragmentQuery() async throws {
        let query =
            """
            query UseFragmentQuery {
                luke: human(id: "1000") {
                    ...HumanFragment
                }
                leia: human(id: "1003") {
                    ...HumanFragment
                }
            }
            fragment HumanFragment on Human {
                name
                homePlanet
            }
            """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func checkTypeOfR2Query() async throws {
        let query =
            """
            query CheckTypeOfR2Query {
                hero {
                    __typename
                    name
                }
            }
            """

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "__typename": "Droid",
                    "name": "R2-D2",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )

        #expect(result == expected)
    }

    @Test func checkTypeOfLukeQuery() async throws {
        let query =
            """
            query CheckTypeOfLukeQuery {
                hero(episode: EMPIRE) {
                    __typename
                    name
                }
            }
            """

        let expected = GraphQLResult(
            data: [
                "hero": [
                    "__typename": "Human",
                    "name": "Luke Skywalker",
                ],
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func secretBackstoryQuery() async throws {
        let query =
            """
            query SecretBackstoryQuery {
                hero {
                    name
                    secretBackstory
                }
            }
            """

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
                ),
            ]
        )

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func secretBackstoryListQuery() async throws {
        let query =
            """
            query SecretBackstoryListQuery {
                hero {
                    name
                    friends {
                        name
                        secretBackstory
                    }
                }
            }
            """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func secretBackstoryAliasQuery() async throws {
        let query =
            """
            query SecretBackstoryAliasQuery {
                mainHero: hero {
                    name
                    story: secretBackstory
                }
            }
            """

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

        let result = try await graphql(
            schema: starWarsSchema,
            request: query
        )
        #expect(result == expected)
    }

    @Test func nonNullableFieldsQuery() async throws {
        let A = try GraphQLObjectType(
            name: "A",
            fields: [:]
        )
        A.fields = { [
            "nullableA": GraphQLField(
                type: A,
                resolve: { _, _, _, _ -> [String: String]? in
                    [:] as [String: String]
                }
            ),
            "nonNullA": GraphQLField(
                type: GraphQLNonNull(A),
                resolve: { _, _, _, _ -> [String: String]? in
                    [:] as [String: String]
                }
            ),
            "throws": GraphQLField(
                type: GraphQLNonNull(GraphQLString),
                resolve: { _, _, _, _ -> [String: String]? in
                    struct 🏃: Error, CustomStringConvertible {
                        let description: String
                    }

                    throw 🏃(description: "catch me if you can.")
                }
            ),
        ] }

        let queryType = try GraphQLObjectType(
            name: "query",
            fields: [
                "nullableA": GraphQLField(
                    type: A,
                    resolve: { _, _, _, _ -> [String: String]? in
                        [:] as [String: String]
                    }
                ),
            ]
        )

        let schema = try GraphQLSchema(
            query: queryType
        )

        let query =
            """
            query {
                nullableA {
                    nullableA {
                        nonNullA {
                            nonNullA {
                                throws
                            }
                        }
                    }
                }
            }
            """

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

        let result = try await graphql(schema: schema, request: query)

        #expect(result == expected)
    }

    @Test func fieldOrderQuery() async throws {
        var result = try await graphql(
            schema: starWarsSchema,
            request: """
            query HeroNameQuery {
                hero {
                    id
                    name
                }
            }
            """
        )
        #expect(result == GraphQLResult(
            data: [
                "hero": [
                    "id": "2001",
                    "name": "R2-D2",
                ],
            ]
        ))

        result = try await graphql(
            schema: starWarsSchema,
            request: """
            query HeroNameQuery {
                hero {
                    id
                    name
                }
            }
            """
        )
        #expect(result != GraphQLResult(
            data: [
                "hero": [
                    "name": "R2-D2",
                    "id": "2001",
                ],
            ]
        ))
    }
}
