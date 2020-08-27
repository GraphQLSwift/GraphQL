import XCTest
@testable import GraphQL

func nameNode(_ name: String) -> Name {
    return Name(value: name)
}

func fieldNode(_ name: Name, _ type: Type) -> FieldDefinition {
    return FieldDefinition(name: name, type: type)
}

func fieldNodeWithDescription(_ description: String? = nil, _ name: Name, _ type: Type) -> FieldDefinition {
    return FieldDefinition(description: description, name: name, type: type)
}

func typeNode(_ name: String) -> NamedType {
    return NamedType(name: nameNode(name))
}

func enumValueNode(_ name: String) -> EnumValueDefinition {
    return EnumValueDefinition(name: nameNode(name))
}

func enumValueWithDescriptionNode(_ description: String, _ name: String) -> EnumValueDefinition {
    return EnumValueDefinition(description: description, name: nameNode(name))
}

func fieldNodeWithArgs(_ name: Name, _ type: Type, _ args: [InputValueDefinition]) -> FieldDefinition {
    return FieldDefinition(name: name, arguments: args, type: type)
}

func inputValueNode(_ name: Name, _ type: Type, _ defaultValue: Value? = nil) -> InputValueDefinition {
    return InputValueDefinition(name: name, type: type, defaultValue: defaultValue)
}

func inputValueWithDescriptionNode(_ description: String,
                                   _ name: Name,
                                   _ type: Type,
                                   _ defaultValue: Value? = nil) -> InputValueDefinition {
    return InputValueDefinition(description: description, name: name, type: type, defaultValue: defaultValue)
}

func namedTypeNode(_ name: String ) -> NamedType {
    return NamedType(name: nameNode(name))
}

class SchemaParserTests : XCTestCase {
    func testSimpleType() throws {
        let source = "type Hello { world: String }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleExtension() throws {
        let source = "extend type Hello { world: String }"

        let expected = Document(
            definitions: [
                TypeExtensionDefinition(
                    definition: ObjectTypeDefinition(
                        name: nameNode("Hello"),
                        fields: [
                            fieldNode(
                                nameNode("world"),
                                typeNode("String")
                            )
                        ]
                    )
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleNonNullType() throws {
        let source = "type Hello { world: String! }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            NonNullType(
                                type: typeNode("String")
                            )
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleTypeInheritingInterface() throws {
        let source = "type Hello implements World { }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    interfaces: [typeNode("World")]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleTypeInheritingMultipleInterfaces() throws {
        let source = "type Hello implements Wo, rld { }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    interfaces: [
                        typeNode("Wo"),
                        typeNode("rld"),
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSingleValueEnum() throws {
        let source = "enum Hello { WORLD }"

        let expected = Document(
            definitions: [
                EnumTypeDefinition(
                    name: nameNode("Hello"),
                    values: [
                        enumValueNode("WORLD"),
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testDoubleValueEnum() throws {
        let source = "enum Hello { WO, RLD }"

        let expected = Document(
            definitions: [
                EnumTypeDefinition(
                    name: nameNode("Hello"),
                    values: [
                        enumValueNode("WO"),
                        enumValueNode("RLD"),
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInterface() throws {
        let source = "interface Hello { world: String }"

        let expected = Document(
            definitions: [
                InterfaceTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleFieldWithArg() throws {
        let source = "type Hello { world(flag: Boolean): String }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithArgs(
                            nameNode("world"),
                            typeNode("String"),
                            [
                                inputValueNode(
                                    nameNode("flag"),
                                    typeNode("Boolean")
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleFieldWithArgDefaultValue() throws {
        let source = "type Hello { world(flag: Boolean = true): String }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithArgs(
                            nameNode("world"),
                            typeNode("String"),
                            [
                                inputValueNode(
                                    nameNode("flag"),
                                    typeNode("Boolean"),
                                    BooleanValue(value: true)
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleFieldWithListArg() throws {
        let source = "type Hello { world(things: [String]): String }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithArgs(
                            nameNode("world"),
                            typeNode("String"),
                            [
                                inputValueNode(
                                    nameNode("things"),
                                    ListType(type: typeNode("String"))
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleFieldWithTwoArgs() throws {
        let source = "type Hello { world(argOne: Boolean, argTwo: Int): String }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithArgs(
                            nameNode("world"),
                            typeNode("String"),
                            [
                                inputValueNode(
                                    nameNode("argOne"),
                                    typeNode("Boolean")
                                ),
                                inputValueNode(
                                    nameNode("argTwo"),
                                    typeNode("Int")
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleUnion() throws {
        let source = "union Hello = World"

        let expected = Document(
            definitions: [
                UnionTypeDefinition(
                    name: nameNode("Hello"),
                    types: [
                        typeNode("World"),
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUnionTwoTypes() throws {
        let source = "union Hello = Wo | Rld"

        let expected = Document(
            definitions: [
                UnionTypeDefinition(
                    name: nameNode("Hello"),
                    types: [
                        typeNode("Wo"),
                        typeNode("Rld"),
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testScalar() throws {
        let source = "scalar Hello"

        let expected = Document(
            definitions: [
                ScalarTypeDefinition(
                    name: nameNode("Hello")
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInputObject() throws {
        let source = "input Hello { world: String }"

        let expected = Document(
            definitions: [
                InputObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        inputValueNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInputObjectWithArgs() throws {
        let source = "input Hello { world(foo: Int): String }"
        XCTAssertThrowsError(try parse(source: source))
    }
    
    func testSimpleSchema() throws {
        let source = "schema { query: Hello }"
        let expected = SchemaDefinition(
                directives: [],
                                        operationTypes: [
                                            OperationTypeDefinition(
                                                operation: .query,
                                                type: namedTypeNode("Hello")
                                            )
                                        ]
                                    )
        let result = try parse(source: source)
        XCTAssert(result.definitions[0] == expected)
    }

    // Description tests
    
    func testTypeWithDescription() throws {
        let source = #""The Hello type" type Hello { world: String }"#
        
        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    description: "The Hello type",
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testTypeWitMultilinehDescription() throws {
        let source = #"""
            """
            The Hello type.
            Multi-line description
            """
            type Hello {
                world: String
            }
            """#
        
        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    description: "The Hello type.\nMulti-line description",
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testDirectiveDesciption() throws {
        let source = #""directive description" directive @Test(a: String = "hello") on FIELD"#
        
        let expected: Document = Document(
            definitions: [
                DirectiveDefinition(loc: nil,
                                    description: "directive description",
                                    name:  nameNode("Test"),
                                    arguments: [
                                        inputValueNode(
                                            nameNode("a"),
                                            typeNode("String"),
                                            StringValue(value: "hello")
                                        )
                                    ],
                                    locations: [
                                        nameNode("FIELD")
                                    ])
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testDirectiveMultilineDesciption() throws {
        let source = #"""
                """
                directive description
                """
                directive @Test(a: String = "hello") on FIELD
                """#
        let expected: Document = Document(
            definitions: [
                DirectiveDefinition(loc: nil,
                                    description: "directive description",
                                    name:  nameNode("Test"),
                                    arguments: [
                                        inputValueNode(
                                            nameNode("a"),
                                            typeNode("String"),
                                            StringValue(value: "hello")
                                        )
                                    ],
                                    locations: [
                                        nameNode("FIELD")
                                    ])
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testSimpleSchemaWithDescription() throws {
        let source = #""Hello Schema" schema { query: Hello } "#
        
        let expected = SchemaDefinition(
            description: "Hello Schema",
            directives: [],
            operationTypes: [
                OperationTypeDefinition(
                    operation: .query,
                    type: namedTypeNode("Hello")
                )
            ]
        )
        let result = try parse(source: source)
        XCTAssert(result.definitions[0] == expected)
    }
    
    func testScalarWithDescription() throws {
        let source = #""Hello Scaler Test" scalar Hello"#
        
        let expected = Document(
            definitions: [
                ScalarTypeDefinition(
                    description: "Hello Scaler Test",
                    name: nameNode("Hello")
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testSimpleInterfaceWithDescription() throws {
        let source = #""Hello World Interface" interface Hello { world: String } "#
        
        let expected = Document(
            definitions: [
                InterfaceTypeDefinition(
                    description: "Hello World Interface",
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testSimpleUnionWithDescription() throws {
        let source = #""Hello World Union!" union Hello = World "#
        
        let expected = Document(
            definitions: [
                UnionTypeDefinition(
                    description: "Hello World Union!",
                    name: nameNode("Hello"),
                    types: [
                        typeNode("World"),
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testSingleValueEnumDescription() throws {
        let source = #""Hello World Enum..." enum Hello { WORLD } "#
        
        let expected = Document(
            definitions: [
                EnumTypeDefinition(
                    description: "Hello World Enum...",
                    name: nameNode("Hello"),
                    values: [
                        enumValueNode("WORLD"),
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testSimpleInputObjectWithDescription() throws {
        let source = #""Hello Input Object" input Hello { world: String }"#
        
        let expected = Document(
            definitions: [
                InputObjectTypeDefinition(
                    description: "Hello Input Object",
                    name: nameNode("Hello"),
                    fields: [
                        inputValueNode(
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    // Test Fields and values with optional descriptions
    
    func testSingleValueEnumWithDescription() throws {
        let source = """
            enum Hello {
                "world description"
                WORLD
                "Hello there"
                HELLO
            }
            """
        
        let expected = Document(
            definitions: [
                EnumTypeDefinition(
                    name: nameNode("Hello"),
                    values: [
                        enumValueWithDescriptionNode("world description", "WORLD"),
                        enumValueWithDescriptionNode("Hello there", "HELLO")
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
    func testTypeFieldWithDescription() throws {
        let source = #"type Hello { "The world field." world: String } "#
        
        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithDescription(
                            "The world field.",
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testTypeFieldWithMultilineDescription() throws {
        let source = #"""
            type Hello {
                """
                The world
                field.
                """
                world: String
            }
            """#
        
        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        fieldNodeWithDescription(
                            "The world\nfield.",
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected, "\(dump(result)) \n\n\(dump(expected))")
    }

    
    func testSimpleInputObjectFieldWithDescription() throws {
        let source = #"input Hello { "World field" world: String }"#
        
        let expected = Document(
            definitions: [
                InputObjectTypeDefinition(
                    name: nameNode("Hello"),
                    fields: [
                        inputValueWithDescriptionNode(
                            "World field",
                            nameNode("world"),
                            typeNode("String")
                        )
                    ]
                )
            ]
        )
        
        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
    
}
