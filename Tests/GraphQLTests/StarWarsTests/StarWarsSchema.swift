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

// TODO: implement MapRepresentable automatically for RawRepresentables
extension Episode : MapRepresentable {
    var map: Map {
        return rawValue.map
    }
}

extension Human : MapFallibleRepresentable {}
extension Droid : MapFallibleRepresentable {}

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
let EpisodeEnum = try! GraphQLEnumType(
    name: "Episode",
    description: "One of the films in the Star Wars Trilogy",
    values: [
        "NEWHOPE": GraphQLEnumValue(
            value: Episode.newHope,
            description: "Released in 1977."
        ),
        "EMPIRE": GraphQLEnumValue(
            value: Episode.empire,
            description: "Released in 1980."
        ),
        "JEDI": GraphQLEnumValue(
            value: Episode.jedi,
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
let CharacterInterface = try! GraphQLInterfaceType(
    name: "Character",
    description: "A character in the Star Wars Trilogy",
    fields: [
        "id": GraphQLField(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the character."
        ),
        "name": GraphQLField(
            type: GraphQLString,
            description: "The name of the character."
        ),
        "friends": GraphQLField(
            type: GraphQLList(GraphQLTypeReference("Character")),
            description: "The friends of the character, or an empty list if they have none."
        ),
        "appearsIn": GraphQLField(
            type: GraphQLList(EpisodeEnum),
            description: "Which movies they appear in."
        ),
        "secretBackstory": GraphQLField(
            type: GraphQLString,
            description: "All secrets about their past."
        ),
    ],
    resolveType: { character, _, _ in
        switch character {
        case is Human:
            return "Human"
        default:
            return "Droid"
        }
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
let HumanType = try! GraphQLObjectType(
    name: "Human",
    description: "A humanoid creature in the Star Wars universe.",
    fields: [
        "id": GraphQLField(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the human."
        ),
        "name": GraphQLField(
            type: GraphQLString,
            description: "The name of the human."
        ),
        "friends": GraphQLField(
            type: GraphQLList(CharacterInterface),
            description: "The friends of the human, or an empty list if they " +
            "have none.",
            resolve: { human, _, _, eventLoopGroup, _ in
                return eventLoopGroup.next().newSucceededFuture(result: getFriends(character: human as! Human))
            }
        ),
        "appearsIn": GraphQLField(
            type: GraphQLList(EpisodeEnum),
            description: "Which movies they appear in."
        ),
        "homePlanet": GraphQLField(
            type: GraphQLString,
            description: "The home planet of the human, or null if unknown."
        ),
        "secretBackstory": GraphQLField(
            type: GraphQLString,
            description: "Where are they from and how they came to be who they are.",
            resolve: { _, _, _, _, _ in
                struct Secret : Error, CustomStringConvertible {
                    let description: String
                }

                throw Secret(description: "secretBackstory is secret.")
            }
        ),
    ],
    interfaces: [CharacterInterface],
    isTypeOf: { source, _, _ in
        source is Human
    }
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
let DroidType = try! GraphQLObjectType(
    name: "Droid",
    description: "A mechanical creature in the Star Wars universe.",
    fields: [
        "id": GraphQLField(
            type: GraphQLNonNull(GraphQLString),
            description: "The id of the droid."
        ),
        "name": GraphQLField(
            type: GraphQLString,
            description: "The name of the droid."
        ),
        "friends": GraphQLField(
            type: GraphQLList(CharacterInterface),
            description: "The friends of the droid, or an empty list if they have none.",
            resolve: { droid, _, _, eventLoopGroup, _ in
                return eventLoopGroup.next().newSucceededFuture(result: getFriends(character: droid as! Droid))
            }
        ),
        "appearsIn": GraphQLField(
            type: GraphQLList(EpisodeEnum),
            description: "Which movies they appear in."
        ),
        "secretBackstory": GraphQLField(
            type: GraphQLString,
            description: "Construction date and the name of the designer.",
            resolve: { _, _, _, _, _ in
                struct Secret : Error, CustomStringConvertible {
                    let description: String
                }

                throw Secret(description: "secretBackstory is secret.")
            }
        ),
        "primaryFunction": GraphQLField(
            type: GraphQLString,
            description: "The primary function of the droid."
        ),
    ],
    interfaces: [CharacterInterface],
    isTypeOf: { source, _, _ in
        source is Droid
    }
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
let QueryType = try! GraphQLObjectType(
    name: "Query",
    fields: [
        "hero": GraphQLField(
            type: CharacterInterface,
            args: [
                "episode": GraphQLArgument(
                    type: EpisodeEnum,
                    description:
                    "If omitted, returns the hero of the whole saga. If " +
                    "provided, returns the hero of that particular episode."
                )
            ],
            resolve: { _, arguments, _, eventLoopGroup, _ in
                let episode = Episode(arguments["episode"].string)
                return eventLoopGroup.next().newSucceededFuture(result: getHero(episode: episode))
            }
        ),
        "human": GraphQLField(
            type: HumanType,
            args: [
                "id": GraphQLArgument(
                    type: GraphQLNonNull(GraphQLString),
                    description: "id of the human"
                )
            ],
            resolve: { _, arguments, _, eventLoopGroup, _ in
                return eventLoopGroup.next().newSucceededFuture(result: getHuman(id: arguments["id"].string!))
            }
        ),
        "droid": GraphQLField(
            type: DroidType,
            args: [
                "id": GraphQLArgument(
                    type: GraphQLNonNull(GraphQLString),
                    description: "id of the droid"
                )
            ],
            resolve: { _, arguments, _, eventLoopGroup, _ in
                return eventLoopGroup.next().newSucceededFuture(result: getDroid(id: arguments["id"].string!))
            }
        ),
    ]
)

/**
 * Finally, we construct our schema (whose starting query type is the query
 * type we defined above) and export it.
 */
let StarWarsSchema = try! GraphQLSchema(
    query: QueryType,
    types: [HumanType, DroidType]
)
