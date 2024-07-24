@testable import GraphQL

// interface Being {
//  name(surname: Boolean): String
// }
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
    resolveType: { _, _, _ in
        "Unknown"
    }
)

// interface Mammal {
//  mother: Mammal
//  father: Mammal
// }
let ValidationExampleMammal = try! GraphQLInterfaceType(
    name: "Mammal",
    fields: {
        [
            "mother": GraphQLField(type: ValidationExampleMammal),
            "father": GraphQLField(type: ValidationExampleMammal),
        ]
    },
    resolveType: { _, _, _ in
        "Unknown"
    }
)

// interface Pet implements Being {
//  name(surname: Boolean): String
// }
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
        "Unknown"
    }
)

// interface Canine implements Mammal & Being {
//  name(surname: Boolean): String
//  mother: Canine
//  father: Canine
// }
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
    resolveType: { _, _, _ in
        "Unknown"
    }
)

// enum DogCommand {
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

// type Dog implements Being & Pet & Mammal & Canine {
//  name(surname: Boolean): String
//  nickname: String
//  barkVolume: Int
//  barks: Boolean
//  doesKnowCommand(dogCommand: DogCommand): Boolean
//  isHouseTrained(atOtherHomes: Boolean = true): Boolean
//  isAtLocation(x: Int, y: Int): Boolean
//  mother: Dog
//  father: Dog
// }
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
                "dogCommand": GraphQLArgument(type: ValidationExampleDogCommand),
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
                ),
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
                ),
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

// enum FurColor {
//  BROWN
//  BLACK
//  TAN
//  SPOTTED
//  NO_FUR
//  UNKNOWN
// }
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

// type Cat implements Being & Pet {
//  name(surname: Boolean): String
//  nickname: String
//  meows: Boolean
//  meowsVolume: Int
//  furColor: FurColor
// }
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
        "Unknown"
    },
    types: [ValidationExampleCat, ValidationExampleDog]
)

// interface Intelligent {
//   iq: Int
// }
let ValidationExampleIntelligent = try! GraphQLInterfaceType(
    name: "Intelligent",
    fields: [
        "iq": GraphQLField(type: GraphQLInt),
    ],
    resolveType: { _, _, _ in
        "Unknown"
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
    resolveType: { _, _, _ in
        "Unknown"
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
    resolveType: { _, _, _ in
        "Unknown"
    },
    types: [ValidationExampleDog, ValidationExampleHuman]
)

// union HumanOrAlien = Human | Alien
let ValidationExampleHumanOrAlien = try! GraphQLUnionType(
    name: "HumanOrAlien",
    resolveType: { _, _, _ in
        "Unknown"
    },
    types: [ValidationExampleHuman, ValidationExampleAlien]
)

// input ComplexInput {
//   requiredField: Boolean!
//   nonNullField: Boolean! = false
//   intField: Int
//   stringField: String
//   booleanField: Boolean
//   stringListField: [String]
// }
let ValidationExampleComplexInput = try! GraphQLInputObjectType(
    name: "ComplexInput",
    fields: [
        "requiredField": InputObjectField(type: GraphQLNonNull(GraphQLBoolean)),
        "nonNullField": InputObjectField(type: GraphQLNonNull(GraphQLBoolean), defaultValue: false),
        "intField": InputObjectField(type: GraphQLInt),
        "stringField": InputObjectField(type: GraphQLString),
        "booleanField": InputObjectField(type: GraphQLBoolean),
        "stringListField": InputObjectField(type: GraphQLList(GraphQLString)),
    ]
)

// input OneOfInput @oneOf {
//   stringField: String
//   intField: Int
// }
let ValidationExampleOneOfInput = try! GraphQLInputObjectType(
    name: "OneOfInput",
    fields: [
        "stringField": InputObjectField(type: GraphQLString),
        "intField": InputObjectField(type: GraphQLInt),
    ],
    isOneOf: true
)

// type ComplicatedArgs {
//   # TODO List
//   # TODO Coercion
//   # TODO NotNulls
//   intArgField(intArg: Int): String
//   nonNullIntArgField(nonNullIntArg: Int!): String
//   stringArgField(stringArg: String): String
//   booleanArgField(booleanArg: Boolean): String
//   enumArgField(enumArg: FurColor): String
//   floatArgField(floatArg: Float): String
//   idArgField(idArg: ID): String
//   stringListArgField(stringListArg: [String]): String
//   stringListNonNullArgField(stringListNonNullArg: [String!]): String
//   complexArgField(complexArg: ComplexInput): String
//   oneOfArgField(oneOfArg: OneOfInput): String
//   multipleReqs(req1: Int!, req2: Int!): String
//   nonNullFieldWithDefault(arg: Int! = 0): String
//   multipleOpts(opt1: Int = 0, opt2: Int = 0): String
//   multipleOptAndReq(req1: Int!, req2: Int!, opt1: Int = 0, opt2: Int = 0): String
// }
let ValidationExampleComplicatedArgs = try! GraphQLObjectType(
    name: "ComplicatedArgs",
    fields: [
        "intArgField": GraphQLField(
            type: GraphQLString,
            args: ["intArg": GraphQLArgument(type: GraphQLInt)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "nonNullIntArgField": GraphQLField(
            type: GraphQLString,
            args: ["nonNullIntArg": GraphQLArgument(type: GraphQLNonNull(GraphQLInt))],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "stringArgField": GraphQLField(
            type: GraphQLString,
            args: ["stringArg": GraphQLArgument(type: GraphQLString)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "booleanArgField": GraphQLField(
            type: GraphQLString,
            args: ["booleanArg": GraphQLArgument(type: GraphQLBoolean)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "enumArgField": GraphQLField(
            type: GraphQLString,
            args: ["enumArg": GraphQLArgument(type: ValidationExampleFurColor)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "floatArgField": GraphQLField(
            type: GraphQLString,
            args: ["floatArg": GraphQLArgument(type: GraphQLFloat)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "idArgField": GraphQLField(
            type: GraphQLString,
            args: ["idArg": GraphQLArgument(type: GraphQLID)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "stringListArgField": GraphQLField(
            type: GraphQLString,
            args: ["stringListArg": GraphQLArgument(type: GraphQLList(GraphQLString))],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "stringListNonNullArgField": GraphQLField(
            type: GraphQLString,
            args: [
                "stringListNonNullArg": GraphQLArgument(type: GraphQLList(GraphQLNonNull(GraphQLString))),
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "complexArgField": GraphQLField(
            type: GraphQLString,
            args: ["complexArg": GraphQLArgument(type: ValidationExampleComplexInput)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "oneOfArgField": GraphQLField(
            type: GraphQLString,
            args: ["oneOfArg": GraphQLArgument(type: ValidationExampleOneOfInput)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "multipleReqs": GraphQLField(
            type: GraphQLString,
            args: [
                "req1": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                "req2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "nonNullFieldWithDefault": GraphQLField(
            type: GraphQLString,
            args: ["arg": GraphQLArgument(type: GraphQLNonNull(GraphQLInt), defaultValue: 0)],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "multipleOpts": GraphQLField(
            type: GraphQLString,
            args: [
                "opt1": GraphQLArgument(type: GraphQLInt, defaultValue: 0),
                "opt2": GraphQLArgument(type: GraphQLInt, defaultValue: 0),
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
        "multipleOptAndReq": GraphQLField(
            type: GraphQLString,
            args: [
                "req1": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                "req2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                "opt1": GraphQLArgument(type: GraphQLInt, defaultValue: 0),
                "opt2": GraphQLArgument(type: GraphQLInt, defaultValue: 0),
            ],
            resolve: { inputValue, _, _, _ -> String? in
                print(type(of: inputValue))
                return nil
            }
        ),
    ]
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
        "complicatedArgs": GraphQLField(type: ValidationExampleComplicatedArgs),
    ]
)

let ValidationFieldDirective = try! GraphQLDirective(
    name: "onField",
    locations: [.field]
)

let ValidationExampleSchema = try! GraphQLSchema(
    query: ValidationExampleQueryRoot,
    types: [
        ValidationExampleCat,
        ValidationExampleDog,
        ValidationExampleHuman,
        ValidationExampleAlien,
    ],
    directives: {
        var directives = specifiedDirectives
        directives.append(contentsOf: [
            ValidationFieldDirective,
        ])
        return directives
    }()
)
