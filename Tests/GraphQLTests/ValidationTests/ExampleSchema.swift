@testable import GraphQL

//interface Being {
//  name(surname: Boolean): String
//}
let ValidationExampleBeing = try! GraphQLInterfaceType(
    name: "Being",
    fields: [
        "name": GraphQLField(
            type: GraphQLString,
            args: ["surname": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
    ],
    resolveType: { _, _, info in
        return "Unknown"
    }
)

//interface Mammal {
//  mother: Mammal
//  father: Mammal
//}
let ValidationExampleMammal = try! GraphQLInterfaceType(
  name: "Mammal",
  fields: [
    "mother": GraphQLField(type: GraphQLTypeReference("Mammal")),
    "father": GraphQLField(type: GraphQLTypeReference("Mammal")),
  ],
  resolveType: { _, _, _ in
      return "Unknown"
  }
)

//interface Pet implements Being {
//  name(surname: Boolean): String
//}
let ValidationExamplePet = try! GraphQLInterfaceType(
    name: "Pet",
    interfaces: [ValidationExampleBeing],
    fields: [
        "name": GraphQLField(
            type: GraphQLString,
            args: ["surname": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
    ],
    resolveType: { _, _, _ in
        return "Unknown"
    }
)

//interface Canine implements Mammal & Being {
//  name(surname: Boolean): String
//  mother: Canine
//  father: Canine
//}
let ValidationExampleCanine = try! GraphQLInterfaceType(
  name: "Canine",
  interfaces: [ValidationExampleMammal, ValidationExampleBeing],
  fields: [
    "name": GraphQLField(
      type: GraphQLString,
      args: ["surname": GraphQLArgument(type: GraphQLBoolean)]
    ),
    "mother": GraphQLField(
        type: GraphQLTypeReference("Mammal")
    ),
    "father": GraphQLField(
        type: GraphQLTypeReference("Mammal")
    ),
  ],
  resolveType: { _, _, info in
      return "Unknown"
  }
    
)

//enum DogCommand {
//   SIT
//   HEEL
//   DOWN
// }
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

//type Dog implements Being & Pet & Mammal & Canine {
//  name(surname: Boolean): String
//  nickname: String
//  barkVolume: Int
//  barks: Boolean
//  doesKnowCommand(dogCommand: DogCommand): Boolean
//  isHouseTrained(atOtherHomes: Boolean = true): Boolean
//  isAtLocation(x: Int, y: Int): Boolean
//  mother: Dog
//  father: Dog
//}
let ValidationExampleDog = try! GraphQLObjectType(
    name: "Dog",
    fields: [
        "name": GraphQLField(
            type: GraphQLString,
            args: ["surname": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "nickname": GraphQLField(type: GraphQLString) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "barkVolume": GraphQLField(type: GraphQLInt) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "barks": GraphQLField(type: GraphQLBoolean) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "doesKnowCommand": GraphQLField(
            type: GraphQLBoolean,
            args: [
                "dogCommand": GraphQLArgument(type: ValidationExampleDogCommand)
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "isHousetrained": GraphQLField(
            type: GraphQLBoolean,
            args: [
                "atOtherHomes": GraphQLArgument(
                    type: GraphQLBoolean,
                    defaultValue: true
                )
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "isAtLocation": GraphQLField(
            type: GraphQLBoolean,
            args: [
                "x": GraphQLArgument(
                    type: GraphQLInt
                ),
                "y": GraphQLArgument(
                    type: GraphQLInt
                )
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "mother": GraphQLField(
            type: GraphQLTypeReference("Mammal"),
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "father": GraphQLField(
            type: GraphQLTypeReference("Mammal"),
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "owner": GraphQLField(type: ValidationExampleHuman) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
    ],
    interfaces: [
        ValidationExampleBeing,
        ValidationExamplePet,
        ValidationExampleMammal,
        ValidationExampleCanine,
    ]
)

//enum FurColor {
//  BROWN
//  BLACK
//  TAN
//  SPOTTED
//  NO_FUR
//  UNKNOWN
//}
let ValidationExampleFurColor = try! GraphQLEnumType(
  name: "FurColor",
  values: [
    "BROWN": GraphQLEnumValue(value: ["value": 0]),
    "BLACK": GraphQLEnumValue(value: ["value": 1]),
    "TAN": GraphQLEnumValue(value: ["value": 2]),
    "SPOTTED": GraphQLEnumValue(value: ["value": 3]),
    "NO_FUR": GraphQLEnumValue(value: ["value": .null]),
    "UNKNOWN": GraphQLEnumValue(value: ["value": .null]),
  ]
)

//type Cat implements Being & Pet {
//  name(surname: Boolean): String
//  nickname: String
//  meows: Boolean
//  meowsVolume: Int
//  furColor: FurColor
//}
let ValidationExampleCat = try! GraphQLObjectType(
    name: "Cat",
    fields: [
        "name": GraphQLField(
            type: GraphQLString,
            args: ["surname": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "nickname": GraphQLField(type: GraphQLString) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "meows": GraphQLField(type: GraphQLBoolean) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "meowVolume": GraphQLField(type: GraphQLInt) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "furColor": GraphQLField(type: ValidationExampleFurColor) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
    ],
    interfaces: [ValidationExampleBeing, ValidationExamplePet]
)

// union CatOrDog = Cat | Dog
let ValidationExampleCatOrDog = try! GraphQLUnionType(
    name: "CatOrDog",
    resolveType: { _, _, _ in
        return "Unknown"
    },
    types: [ValidationExampleCat, ValidationExampleDog]
)

//interface Intelligent {
//   iq: Int
//}
let ValidationExampleIntelligent = try! GraphQLInterfaceType(
    name: "Intelligent",
    fields: [
        "iq": GraphQLField(type: GraphQLInt),
    ],
    resolveType: { _, _, info in
        return "Unknown"
    }
)

// interface Sentient {
//     name: String!
// }
let ValidationExampleSentient = try! GraphQLInterfaceType(
    name: "Sentient",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
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
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "homePlanet": GraphQLField(type: GraphQLString) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
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
        "name": GraphQLField(
            type: GraphQLNonNull(GraphQLString),
            args: ["surname": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "pets": GraphQLField(
            type: GraphQLList(ValidationExamplePet),
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "iq": GraphQLField(
            type: GraphQLInt,
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
    ],
    interfaces: [ValidationExampleBeing, ValidationExampleIntelligent]
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

// union DogOrHuman = Dog | Human
let ValidationExampleDogOrHuman = try! GraphQLUnionType(
    name: "DogOrHuman",
    resolveType: { _, _, info in
        return "Unknown"
    },
    types: [ValidationExampleDog, ValidationExampleHuman]
)

// union HumanOrAlien = Human | Alien
let ValidationExampleHumanOrAlien = try! GraphQLUnionType(
    name: "HumanOrAlien",
    resolveType: { _, _, info in
        return "Unknown"
    },
    types: [ValidationExampleHuman, ValidationExampleAlien]
)

// type QueryRoot {
//   dog: Dog
// }
let ValidationExampleQueryRoot = try! GraphQLObjectType(
    name: "QueryRoot",
    fields: [
        "dog": GraphQLField(type: ValidationExampleDog) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "catOrDog": GraphQLField(type: ValidationExampleCatOrDog) { inputValue, _, _, _ -> String? in
            print(type(of: inputValue))
            return nil
        },
        "humanOrAlien": GraphQLField(type: ValidationExampleHumanOrAlien),
    ]
)

let ValidationExampleSchema = try! GraphQLSchema(
    query: ValidationExampleQueryRoot,
    types: [
        ValidationExampleCat,
        ValidationExampleDog,
        ValidationExampleHuman,
        ValidationExampleAlien,
    ]
)
