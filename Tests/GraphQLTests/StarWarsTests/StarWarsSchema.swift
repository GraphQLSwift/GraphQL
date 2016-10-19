import GraphQL

/**
 * This is designed to be an end-to-end test, demonstrating
 * the full GraphQL stack.
 *
 * We will create a GraphQL schema that describes the major
 * characters in the original Star Wars trilogy.
 *
 * NOTE: This may contain spoilers for the original Star
 * Wars trilogy.
 */

extension Episode : MapRepresentable {
    var map: Map {
        return rawValue.map
    }
}

extension Character {
    var map: Map {
        return [
            "id": id.map,
            "name": name.map,
            "friends": friends.map,
            "appearsIn": appearsIn.map
        ]
    }
}

/**
 * Using our shorthand to describe type systems, the type system for our
 * Star Wars example is:
 *
 * enum Episode { NEWHOPE, EMPIRE, JEDI }
 *
 * interface Character {
 *   id: String!
 *   name: String
 *   friends: [Character]
 *   appearsIn: [Episode]
 * }
 *
 * type Human : Character {
 *   id: String!
 *   name: String
 *   friends: [Character]
 *   appearsIn: [Episode]
 *   homePlanet: String
 * }
 *
 * type Droid : Character {
 *   id: String!
 *   name: String
 *   friends: [Character]
 *   appearsIn: [Episode]
 *   primaryFunction: String
 * }
 *
 * type Query {
 *   hero(episode: Episode): Character
 *   human(id: String!): Human
 *   droid(id: String!): Droid
 * }
 *
 * We begin by setting up our schema.
 */

/**
 * The original trilogy consists of three movies.
 *
 * This implements the following type system shorthand:
 *   enum Episode { NEWHOPE, EMPIRE, JEDI }
 */
let episodeEnum = try! GraphQLEnumType(
    name: "Episode",
    description: "One of the films in the Star Wars Trilogy",
    values: [
        "NEWHOPE": GraphQLEnumValueConfig(
            value: Episode.newHope.rawValue.map,
            description: "Released in 1977."
        ),
        "EMPIRE": GraphQLEnumValueConfig(
            value: Episode.empire.rawValue.map,
            description: "Released in 1980."
        ),
        "JEDI": GraphQLEnumValueConfig(
            value: Episode.jedi.rawValue.map,
            description: "Released in 1983."
        ),
    ]
)

/**
 * Characters in the Star Wars trilogy are either humans or droids.
 *
 * This implements the following type system shorthand:
 *   interface Character {
 *     id: String!
 *     name: String
 *     friends: [Character]
 *     appearsIn: [Episode]
 *     secretBackstory: String
 *   }
 */
let characterInterface = try! GraphQLInterfaceType(
    name: "Character",
    description: "A character in the Star Wars Trilogy",
    fields: [
        "id": GraphQLFieldConfig(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the character."
        ),
        "name": GraphQLFieldConfig(
            type: GraphQLString,
            description: "The name of the character."
        ),
        "friends": GraphQLFieldConfig(
            type: GraphQLList(GraphQLTypeReference("Character")),
            description: "The friends of the character, or an empty list if they have none."
        ),
        "appearsIn": GraphQLFieldConfig(
            type: GraphQLList(episodeEnum),
            description: "Which movies they appear in."
        ),
        "secretBackstory": GraphQLFieldConfig(
            type: GraphQLString,
            description: "All secrets about their past."
        ),
    ],
    resolveType: { _, _, _ in
        //        return getHuman(id: character["id"]!) ? humanType : droidType
        return .name("Human")
    }
)


/**
 * We define our human type, which implements the character interface.
 *
 * This implements the following type system shorthand:
 *   type Human : Character {
 *     id: String!
 *     name: String
 *     friends: [Character]
 *     appearsIn: [Episode]
 *     secretBackstory: String
 *   }
 */
let humanType = try! GraphQLObjectType(
    name: "Human",
    description: "A humanoid creature in the Star Wars universe.",
    fields: [
        "id": GraphQLFieldConfig(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the human."
        ),
        "name": GraphQLFieldConfig(
            type: GraphQLString,
            description: "The name of the human."
        ),
        "friends": GraphQLFieldConfig(
            type: GraphQLList(characterInterface),
            description: "The friends of the human, or an empty list if they " +
            "have none.",
            resolve: { _, _, _, _ in
                // convert from Map to Character
                // from [Character] to Map
                // getFriends(character: human)
                return .null
            }
        ),
        "appearsIn": GraphQLFieldConfig(
            type: GraphQLList(episodeEnum),
            description: "Which movies they appear in."
        ),
        "homePlanet": GraphQLFieldConfig(
            type: GraphQLString,
            description: "The home planet of the human, or null if unknown."
        ),
        "secretBackstory": GraphQLFieldConfig(
            type: GraphQLString,
            description: "Where are they from and how they came to be who they are.",
            resolve: { _ in
                struct Secret : Error, CustomStringConvertible {
                    let description: String
                }

                throw Secret(description: "secretBackstory is secret.")
            }
        ),
    ],
    interfaces: [characterInterface]
)


/**
 * The other type of character in Star Wars is a droid.
 *
 * This implements the following type system shorthand:
 *   type Droid : Character {
 *     id: String!
 *     name: String
 *     friends: [Character]
 *     appearsIn: [Episode]
 *     secretBackstory: String
 *     primaryFunction: String
 *   }
 */
let droidType = try! GraphQLObjectType(
    name: "Droid",
    description: "A mechanical creature in the Star Wars universe.",
    fields: [
        "id": GraphQLFieldConfig(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the droid."
        ),
        "name": GraphQLFieldConfig(
            type: GraphQLString,
            description: "The name of the droid."
        ),
        "friends": GraphQLFieldConfig(
            type: GraphQLList(characterInterface),
            description: "The friends of the droid, or an empty list if they have none.",
            resolve: { _, _, _, _ in
                // convert from Map to Character
                // from [Character] to Map
                // getFriends(character: droid)
                return .null
            }
        ),
        "appearsIn": GraphQLFieldConfig(
            type: GraphQLList(episodeEnum),
            description: "Which movies they appear in."
        ),
        "secretBackstory": GraphQLFieldConfig(
            type: GraphQLString,
            description: "Construction date and the name of the designer.",
            resolve: { _ in
                struct Secret : Error, CustomStringConvertible {
                    let description: String
                }

                throw Secret(description: "secretBackstory is secret.")
            }
        ),
        "primaryFunction": GraphQLFieldConfig(
            type: GraphQLString,
            description: "The primary function of the droid."
        ),
    ],
    interfaces: [characterInterface]
)


/**
 * This is the type that will be the root of our query, and the
 * entry point into our schema. It gives us the ability to fetch
 * objects by their IDs, as well as to fetch the undisputed hero
 * of the Star Wars trilogy, R2-D2, directly.
 *
 * This implements the following type system shorthand:
 *   type Query {
 *     hero(episode: Episode): Character
 *     human(id: String!): Human
 *     droid(id: String!): Droid
 *   }
 *
 */
let queryType = try! GraphQLObjectType(
    name: "Query",
    fields: [
        "hero": GraphQLFieldConfig(
            type: characterInterface,
            args: [
                "episode": GraphQLArgumentConfig(
                    type: episodeEnum,
                    description:
                    "If omitted, returns the hero of the whole saga. If " +
                    "provided, returns the hero of that particular episode."
                )
            ],
            resolve: { _, args, _, _ in
                let episode = Episode(rawValue: args["episode"]?.string ?? "")
                return getHero(episode: episode).map
            }
        ),
        "human": GraphQLFieldConfig(
            type: humanType,
            args: [
                "id": GraphQLArgumentConfig(
                    type: GraphQLNonNull(GraphQLString),
                    description: "id of the human"
                )
            ],
            resolve: { _, _, _, _ in
                //getHuman(id)
                return .null
            }
        ),
        "droid": GraphQLFieldConfig(
            type: droidType,
            args: [
                "id": GraphQLArgumentConfig(
                    type: GraphQLNonNull(GraphQLString),
                    description: "id of the droid"
                )
            ],
            resolve: { _, _, _, _ in
                //getDroid(id)
                return .null
            }
        ),
    ]
)

/**
 * Finally, we construct our schema (whose starting query type is the query
 * type we defined above) and export it.
 */
let StarWarsSchema = try! GraphQLSchema(
    query: queryType,
    types: [humanType, droidType]
)
