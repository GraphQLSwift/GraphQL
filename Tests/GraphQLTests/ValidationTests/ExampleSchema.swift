@testable import GraphQL

//
// enum DogCommand { SIT, DOWN, HEEL }
//
let ValidationExampleDogCommand = try! GraphQLEnumType(
    name: "DogCommand",
    values: [
        "SIT": GraphQLEnumValue(
            value: "SIT"
        ),
        "DOWN": GraphQLEnumValue(
            value: "DOWN"
        ),
        "HEEL": GraphQLEnumValue(
            value: "HEEL"
        ),
    ]
)

// interface Sentient {
//     name: String!
// }
let ValidationExampleSentient = try! GraphQLInterfaceType(
    name: "Sentient",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
    ],
    resolveType: { _, _, info in
        return "Unknown"
    }
)

// type Alien implements Sentient {
//     name: String!
//     homePlanet: String
// }
let ValidationExampleAlien = try! GraphQLObjectType(
    name: "Alien",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "homePlanet": GraphQLField(type: GraphQLString),
    ],
    interfaces: [ValidationExampleSentient]
)

// type Human implements Sentient {
//     name: String!
//     pets: [Pet!]!
// }
let ValidationExampleHuman = try! GraphQLObjectType(
    name: "Human",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "pets": GraphQLField(type: GraphQLNonNull(GraphQLList(GraphQLNonNull(ValidationExamplePet)))),
    ],
    interfaces: [ValidationExampleSentient]
)

// interface Pet {
//     name: String!
// }
let ValidationExamplePet = try! GraphQLInterfaceType(
    name: "Pet",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
    ],
    resolveType: { _, _, _ in
        return "Unknown"
    }
)

// type Dog implements Pet {
//     name: String!
//     nickname: String
//     barkVolume: Int
//     doesKnowCommand(dogCommand: DogCommand!): Boolean!
//     isHousetrained(atOtherHomes: Boolean): Boolean!
//     owner: Human
// }
let ValidationExampleDog = try! GraphQLObjectType(
    name: "Dog",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "nickname": GraphQLField(type: GraphQLString),
        "barkVolume": GraphQLField(type: GraphQLInt),
        "doesKnowCommand": GraphQLField(
            type: GraphQLNonNull(GraphQLBoolean),
            args: [
                "dogCommand": GraphQLArgument(type: GraphQLNonNull(ValidationExampleDogCommand))
            ]
        ),
        "isHousetrained": GraphQLField(
            type: GraphQLNonNull(GraphQLBoolean),
            args: [
                "atOtherHomes": GraphQLArgument(type: GraphQLBoolean)
            ]
        ),
        "owner": GraphQLField(type: ValidationExampleHuman),
    ],
    interfaces: [ValidationExamplePet]
)

// enum CatCommand { JUMP }
let ValidationExampleCatCommand = try! GraphQLEnumType(
    name: "CatCommand",
    values: [
        "JUMP": GraphQLEnumValue(
            value: "JUMP"
        ),
    ]
)

// type Cat implements Pet {
//     name: String!
//     nickname: String
//     doesKnowCommand(catCommand: CatCommand!): Boolean!
//     meowVolume: Int
// }
let ValidationExampleCat = try! GraphQLObjectType(
    name: "Cat",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "nickname": GraphQLField(type: GraphQLString),
        "doesKnowCommand": GraphQLField(
            type: GraphQLNonNull(GraphQLBoolean),
            args: [
                "catCommand": GraphQLArgument(type: GraphQLNonNull(ValidationExampleCatCommand))
            ]
        ),
        "meowVolume": GraphQLField(type: GraphQLInt),
    ],
    interfaces: [ValidationExamplePet]
)

// union CatOrDog = Cat | Dog
let ValidationExampleCatOrDog = try! GraphQLUnionType(
    name: "CatOrDog",
    types: [ValidationExampleCat, ValidationExampleDog]
)

// union DogOrHuman = Dog | Human
let ValidationExampleDogOrHuman = try! GraphQLUnionType(
    name: "DogOrHuman",
    types: [ValidationExampleDog, ValidationExampleHuman]
)

// union HumanOrAlien = Human | Alien
let ValidationExampleHumanOrAlien = try! GraphQLUnionType(
    name: "HumanOrAlien",
    types: [ValidationExampleHuman, ValidationExampleAlien]
)

// type QueryRoot {
//   dog: Dog
// }
let ValidationExampleQueryRoot = try! GraphQLObjectType(
    name: "QueryRoot",
    fields: [
        "dog": GraphQLField(type: ValidationExampleDog),
    ]
)

let ValidationExampleSchema = try! GraphQLSchema(
    query: ValidationExampleQueryRoot,
    types: [
        ValidationExampleDog,
    ]
)
