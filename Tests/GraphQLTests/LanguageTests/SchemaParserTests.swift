@testable import GraphQL
import XCTest

func nameNode(_ name: String) -> Name {
    return Name(value: name)
}

func fieldNode(_ name: Name, _ type: Type) -> FieldDefinition {
    return FieldDefinition(name: name, type: type)
}

func fieldNodeWithDescription(
    _ description: StringValue? = nil,
    _ name: Name,
    _ type: Type
) -> FieldDefinition {
    return FieldDefinition(description: description, name: name, type: type)
}

func typeNode(_ name: String) -> NamedType {
    return NamedType(name: nameNode(name))
}

func enumValueNode(_ name: String) -> EnumValueDefinition {
    return EnumValueDefinition(name: nameNode(name))
}

func enumValueWithDescriptionNode(
    _ description: StringValue?,
    _ name: String
) -> EnumValueDefinition {
    return EnumValueDefinition(description: description, name: nameNode(name))
}

func fieldNodeWithArgs(
    _ name: Name,
    _ type: Type,
    _ args: [InputValueDefinition]
) -> FieldDefinition {
    return FieldDefinition(name: name, arguments: args, type: type)
}

func inputValueNode(
    _ name: Name,
    _ type: Type,
    _ defaultValue: Value? = nil
) -> InputValueDefinition {
    return InputValueDefinition(name: name, type: type, defaultValue: defaultValue)
}

func inputValueWithDescriptionNode(
    _ description: StringValue?,
    _ name: Name,
    _ type: Type,
    _ defaultValue: Value? = nil
) -> InputValueDefinition {
    return InputValueDefinition(
        description: description,
        name: name,
        type: type,
        defaultValue: defaultValue
    )
}

func namedTypeNode(_ name: String) -> NamedType {
    return NamedType(name: nameNode(name))
}

class SchemaParserTests: XCTestCase {
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
                        ),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testParsesTypeWithDescriptionString() throws {
        let doc = try parse(source: """
        "Description"
        type Hello {
          world: String
        }
        """)

        let type = try XCTUnwrap(doc.definitions[0] as? ObjectTypeDefinition)

        XCTAssertEqual(
            type.description?.value,
            "Description"
        )
    }

    func testParsesTypeWithDescriptionMultiLineString() throws {
        let doc = try parse(source: #"""
        """
        Description
        """
        # Even with comments between them
        type Hello {
          world: String
        }
        """#)

        let type = try XCTUnwrap(doc.definitions[0] as? ObjectTypeDefinition)

        XCTAssertEqual(
            type.description?.value,
            "Description"
        )
    }

    func testParsesSchemaWithDescriptionMultiLineString() throws {
        let doc = try parse(source: """
        "Description"
        schema {
          query: Foo
        }
        """)

        let type = try XCTUnwrap(doc.definitions[0] as? SchemaDefinition)

        XCTAssertEqual(
            type.description?.value,
            "Description"
        )
    }

    func testDescriptionFollowedBySomethingOtherThanTypeSystemDefinitionThrows() throws {
        XCTAssertThrowsError(
            try parse(source: #""Description" 1"#)
        )
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
                            ),
                        ]
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testObjectExtensionWithoutFields() throws {
        XCTAssertEqual(
            try parse(source: "extend type Hello implements Greeting"),
            Document(
                definitions: [
                    TypeExtensionDefinition(
                        definition: ObjectTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("Greeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                ]
            )
        )
    }

    func testInterfaceExtensionWithoutFields() throws {
        XCTAssertEqual(
            try parse(source: "extend interface Hello implements Greeting"),
            Document(
                definitions: [
                    InterfaceExtensionDefinition(
                        definition: InterfaceTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("Greeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                ]
            )
        )
    }

    func testObjectExtensionWithoutFieldsFollowedByExtension() throws {
        XCTAssertEqual(
            try parse(source: """
            extend type Hello implements Greeting

            extend type Hello implements SecondGreeting
            """),
            Document(
                definitions: [
                    TypeExtensionDefinition(
                        definition: ObjectTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("Greeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                    TypeExtensionDefinition(
                        definition: ObjectTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("SecondGreeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                ]
            )
        )
    }

    func testExtensionWithoutAnythingThrows() throws {
        try XCTAssertThrowsError(parse(source: "extend scalar Hello"))
        try XCTAssertThrowsError(parse(source: "extend type Hello"))
        try XCTAssertThrowsError(parse(source: "extend interface Hello"))
        try XCTAssertThrowsError(parse(source: "extend union Hello"))
        try XCTAssertThrowsError(parse(source: "extend enum Hello"))
        try XCTAssertThrowsError(parse(source: "extend input Hello"))
    }

    func testInterfaceExtensionWithoutFieldsFollowedByExtension() throws {
        XCTAssertEqual(
            try parse(source: """
            extend interface Hello implements Greeting

            extend interface Hello implements SecondGreeting
            """),
            Document(
                definitions: [
                    InterfaceExtensionDefinition(
                        definition: InterfaceTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("Greeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                    InterfaceExtensionDefinition(
                        definition: InterfaceTypeDefinition(
                            name: nameNode("Hello"),
                            interfaces: [typeNode("SecondGreeting")],
                            directives: [],
                            fields: []
                        )
                    ),
                ]
            )
        )
    }

    func testObjectExtensionDoNotIncludeDescriptions() throws {
        XCTAssertThrowsError(
            try parse(source: """
            "Description"
            extend type Hello {
              world: String
            }
            """)
        )

        XCTAssertThrowsError(
            try parse(source: """
            extend "Description" type Hello {
              world: String
            }
            """)
        )
    }

    func testInterfaceExtensionDoNotIncludeDescriptions() throws {
        XCTAssertThrowsError(
            try parse(source: """
            "Description"
            extend interface Hello {
              world: String
            }
            """)
        )

        XCTAssertThrowsError(
            try parse(source: """
            extend "Description" interface Hello {
              world: String
            }
            """)
        )
    }

    func testSchemaExtension() throws {
        XCTAssertEqual(
            try parse(source: """
            extend schema {
              mutation: Mutation
            }
            """),
            Document(
                definitions: [
                    SchemaExtensionDefinition(
                        definition: SchemaDefinition(
                            directives: [],
                            operationTypes: [
                                OperationTypeDefinition(
                                    operation: .mutation,
                                    type: .init(name: .init(value: "Mutation"))
                                ),
                            ]
                        )
                    ),
                ]
            )
        )
    }

    func testSchemaExtensionWithOnlyDirectives() throws {
        XCTAssertEqual(
            try parse(source: "extend schema @directive"),
            Document(
                definitions: [
                    SchemaExtensionDefinition(
                        definition: SchemaDefinition(
                            directives: [
                                Directive(name: .init(value: "directive")),
                            ],
                            operationTypes: []
                        )
                    ),
                ]
            )
        )
    }

    func testSchemaExtensionWithoutAnythingThrows() throws {
        XCTAssertThrowsError(
            try parse(source: "extend schema")
        )
    }

    func testSchemaExtensionWithInvalidOperationTypeThrows() throws {
        XCTAssertThrowsError(
            try parse(source: "extend schema { unknown: SomeType }")
        )
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
                        ),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInterfaceInheritingInterface() throws {
        XCTAssertEqual(
            try parse(source: "interface Hello implements World { field: String }"),
            Document(
                definitions: [
                    InterfaceTypeDefinition(
                        name: nameNode("Hello"),
                        interfaces: [typeNode("World")],
                        fields: [
                            FieldDefinition(
                                name: .init(value: "field"),
                                type: NamedType(name: .init(value: "String"))
                            ),
                        ]
                    ),
                ]
            )
        )
    }

    func testSimpleTypeInheritingInterface() throws {
        let source = "type Hello implements World { }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    interfaces: [typeNode("World")]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleTypeInheritingMultipleInterfaces() throws {
        let source = "type Hello implements Wo & rld { }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    interfaces: [
                        typeNode("Wo"),
                        typeNode("rld"),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInterfaceInheritingMultipleInterfaces() throws {
        XCTAssertEqual(
            try parse(source: "interface Hello implements Wo & rld { field: String }"),
            Document(
                definitions: [
                    InterfaceTypeDefinition(
                        name: nameNode("Hello"),
                        interfaces: [
                            typeNode("Wo"),
                            typeNode("rld"),
                        ],
                        fields: [
                            FieldDefinition(
                                name: .init(value: "field"),
                                type: NamedType(name: .init(value: "String"))
                            ),
                        ]
                    ),
                ]
            )
        )
    }

    func testSimpleTypeInheritingMultipleInterfacesWithLeadingAmbersand() throws {
        let source = "type Hello implements & Wo & rld { }"

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(
                    name: nameNode("Hello"),
                    interfaces: [
                        typeNode("Wo"),
                        typeNode("rld"),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleInterfaceInheritingMultipleInterfacesWithLeadingAmbersand() throws {
        XCTAssertEqual(
            try parse(source: "interface Hello implements & Wo & rld { field: String }"),
            Document(
                definitions: [
                    InterfaceTypeDefinition(
                        name: nameNode("Hello"),
                        interfaces: [
                            typeNode("Wo"),
                            typeNode("rld"),
                        ],
                        fields: [
                            FieldDefinition(
                                name: .init(value: "field"),
                                type: NamedType(name: .init(value: "String"))
                            ),
                        ]
                    ),
                ]
            )
        )
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
                ),
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
                ),
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
                        ),
                    ]
                ),
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
                                ),
                            ]
                        ),
                    ]
                ),
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
                                ),
                            ]
                        ),
                    ]
                ),
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
                                ),
                            ]
                        ),
                    ]
                ),
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
                                ),
                            ]
                        ),
                    ]
                ),
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
                ),
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
                ),
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
                ),
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
                        ),
                    ]
                ),
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
                ),
            ]
        )
        let result = try parse(source: source)
        XCTAssert(result.definitions[0] == expected)
    }

    // Description tests

    func testTypeWithDescription() throws {
        let source = #""The Hello type" type Hello { world: String }"#

        let expected = ObjectTypeDefinition(
            description: StringValue(value: "The Hello type", block: false),
            name: nameNode("Hello"),
            fields: [
                fieldNode(
                    nameNode("world"),
                    typeNode("String")
                ),
            ]
        )

        let result = try parse(source: source)
        let firstDefinition = try XCTUnwrap(result.definitions[0] as? ObjectTypeDefinition)
        XCTAssertEqual(
            firstDefinition,
            expected,
            """
            \(dump(firstDefinition))
            \(dump(expected))
            """
        )
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
                    description: StringValue(
                        value: "The Hello type.\nMulti-line description",
                        block: true
                    ),
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testDirectiveDesciption() throws {
        let source = #""directive description" directive @Test(a: String = "hello") on FIELD"#

        let expected = Document(
            definitions: [
                DirectiveDefinition(
                    loc: nil,
                    description: StringValue(
                        value: "directive description",
                        block: false
                    ),
                    name: nameNode("Test"),
                    arguments: [
                        inputValueNode(
                            nameNode("a"),
                            typeNode("String"),
                            StringValue(value: "hello", block: false)
                        ),
                    ],
                    locations: [
                        nameNode("FIELD"),
                    ]
                ),
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
        let expected = Document(
            definitions: [
                DirectiveDefinition(
                    loc: nil,
                    description: StringValue(
                        value: "directive description",
                        block: true
                    ),
                    name: nameNode("Test"),
                    arguments: [
                        inputValueNode(
                            nameNode("a"),
                            typeNode("String"),
                            StringValue(value: "hello", block: false)
                        ),
                    ],
                    locations: [
                        nameNode("FIELD"),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testSimpleSchemaWithDescription() throws {
        let source = #""Hello Schema" schema { query: Hello } "#

        let expected = SchemaDefinition(
            description: StringValue(value: "Hello Schema", block: false),
            directives: [],
            operationTypes: [
                OperationTypeDefinition(
                    operation: .query,
                    type: namedTypeNode("Hello")
                ),
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
                    description: StringValue(value: "Hello Scaler Test", block: false),
                    name: nameNode("Hello")
                ),
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
                    description: StringValue(value: "Hello World Interface", block: false),
                    name: nameNode("Hello"),
                    fields: [
                        fieldNode(
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
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
                    description: StringValue(value: "Hello World Union!", block: false),
                    name: nameNode("Hello"),
                    types: [
                        typeNode("World"),
                    ]
                ),
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
                    description: StringValue(value: "Hello World Enum...", block: false),
                    name: nameNode("Hello"),
                    values: [
                        enumValueNode("WORLD"),
                    ]
                ),
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
                    description: StringValue(value: "Hello Input Object", block: false),
                    name: nameNode("Hello"),
                    fields: [
                        inputValueNode(
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
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
                        enumValueWithDescriptionNode(
                            StringValue(value: "world description", block: false),
                            "WORLD"
                        ),
                        enumValueWithDescriptionNode(
                            StringValue(value: "Hello there", block: false),
                            "HELLO"
                        ),
                    ]
                ),
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
                            StringValue(value: "The world field.", block: false),
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
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
                            StringValue(value: "The world\nfield.", block: true),
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
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
                            StringValue(value: "World field", block: false),
                            nameNode("world"),
                            typeNode("String")
                        ),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUndefinedType() throws {
        let source = #"type UndefinedType"#

        let expected = Document(
            definitions: [
                ObjectTypeDefinition(name: nameNode("UndefinedType")),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUndefinedInterfaceType() throws {
        let source = #"interface UndefinedInterface"#

        let expected = Document(
            definitions: [
                InterfaceTypeDefinition(
                    name: nameNode("UndefinedInterface"),
                    fields: []
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testInterfaceExtensionType() throws {
        let source = #"extend interface Bar @onInterface"#

        let expected = Document(
            definitions: [
                InterfaceExtensionDefinition(
                    definition: InterfaceTypeDefinition(
                        name: nameNode("Bar"),
                        directives: [
                            Directive(name: nameNode("onInterface")),
                        ],
                        fields: []
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUnionPipe() throws {
        let source = #"union AnnotatedUnionTwo @onUnion = | A | B"#

        let expected = Document(
            definitions: [
                UnionTypeDefinition(
                    name: nameNode("AnnotatedUnionTwo"),
                    directives: [
                        Directive(name: nameNode("onUnion")),
                    ],
                    types: [
                        NamedType(name: nameNode("A")),
                        NamedType(name: nameNode("B")),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testExtendScalar() throws {
        let source = #"extend scalar CustomScalar @onScalar"#

        let expected = Document(
            definitions: [
                ScalarExtensionDefinition(
                    definition: ScalarTypeDefinition(
                        name: nameNode("CustomScalar"),
                        directives: [
                            Directive(name: nameNode("onScalar")),
                        ]
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUndefinedUnion() throws {
        let source = #"union UndefinedUnion"#

        let expected = Document(
            definitions: [
                UnionTypeDefinition(
                    name: nameNode("UndefinedUnion"),
                    types: []
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testExtendUnion() throws {
        let source = #"extend union Feed = Photo | Video"#

        let expected = Document(
            definitions: [
                UnionExtensionDefinition(
                    definition: UnionTypeDefinition(
                        name: nameNode("Feed"),
                        types: [
                            namedTypeNode("Photo"),
                            namedTypeNode("Video"),
                        ]
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUndefinedEnum() throws {
        let source = #"enum UndefinedEnum"#

        let expected = Document(
            definitions: [
                EnumTypeDefinition(
                    name: nameNode("UndefinedEnum"),
                    values: []
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testEnumExtension() throws {
        let source = #"extend enum Site @onEnum"#

        let expected = Document(
            definitions: [
                EnumExtensionDefinition(
                    definition: EnumTypeDefinition(
                        name: nameNode("Site"),
                        directives: [
                            Directive(name: nameNode("onEnum")),
                        ],
                        values: []
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testUndefinedInput() throws {
        let source = #"input UndefinedInput"#

        let expected = Document(
            definitions: [
                InputObjectTypeDefinition(
                    name: nameNode("UndefinedInput"),
                    fields: []
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testInputExtension() throws {
        let source = #"extend input InputType @include"#

        let expected = Document(
            definitions: [
                InputObjectExtensionDefinition(
                    definition: InputObjectTypeDefinition(
                        name: nameNode("InputType"),
                        directives: [
                            Directive(name: Name(value: "include")),
                        ],
                        fields: []
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testDirectivePipe() throws {
        let source = """
        directive @include2 on
            | FIELD
            | FRAGMENT_SPREAD
            | INLINE_FRAGMENT
        """

        let expected = Document(
            definitions: [
                DirectiveDefinition(
                    name: nameNode("include2"),
                    locations: [
                        nameNode("FIELD"),
                        nameNode("FRAGMENT_SPREAD"),
                        nameNode("INLINE_FRAGMENT"),
                    ]
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testDirectiveRepeatable() throws {
        let source = """
        directive @myRepeatableDir repeatable on
          | OBJECT
          | INTERFACE
        """

        let expected = Document(
            definitions: [
                DirectiveDefinition(
                    name: nameNode("myRepeatableDir"),
                    locations: [
                        nameNode("OBJECT"),
                        nameNode("INTERFACE"),
                    ],
                    repeatable: true
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }

    func testKitchenSink() throws {
        guard
            let url = Bundle.module.url(
                forResource: "schema-kitchen-sink",
                withExtension: "graphql"
            ),
            let kitchenSink = try? String(contentsOf: url)
        else {
            XCTFail("Could not load kitchen sink")
            return
        }

        _ = try parse(source: kitchenSink)
    }

    func testSchemeExtension() throws {
        // Based on Apollo Federation example schema: https://github.com/apollographql/apollo-federation-subgraph-compatibility/blob/main/COMPATIBILITY.md#products-schema-to-be-implemented-by-library-maintainers
        let source =
            """
            extend schema
              @link(
                url: "https://specs.apollo.dev/federation/v2.0",
                import: [
                  "@extends",
                  "@external",
                  "@key",
                  "@inaccessible",
                  "@override",
                  "@provides",
                  "@requires",
                  "@shareable",
                  "@tag"
                ]
              )
            """

        let expected = Document(
            definitions: [
                SchemaExtensionDefinition(
                    definition: SchemaDefinition(
                        directives: [
                            Directive(
                                name: nameNode("link"),
                                arguments: [
                                    Argument(
                                        name: nameNode("url"),
                                        value: StringValue(
                                            value: "https://specs.apollo.dev/federation/v2.0",
                                            block: false
                                        )
                                    ),
                                    Argument(
                                        name: nameNode("import"),
                                        value: ListValue(values: [
                                            StringValue(value: "@extends", block: false),
                                            StringValue(value: "@external", block: false),
                                            StringValue(value: "@key", block: false),
                                            StringValue(value: "@inaccessible", block: false),
                                            StringValue(value: "@override", block: false),
                                            StringValue(value: "@provides", block: false),
                                            StringValue(value: "@requires", block: false),
                                            StringValue(value: "@shareable", block: false),
                                            StringValue(value: "@tag", block: false),
                                        ])
                                    ),
                                ]
                            ),
                        ],
                        operationTypes: []
                    )
                ),
            ]
        )

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
}
