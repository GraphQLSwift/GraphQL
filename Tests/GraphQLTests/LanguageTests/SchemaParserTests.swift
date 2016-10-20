import XCTest
@testable import GraphQL

func nameNode(_ name: String) -> Name {
    return Name(value: name)
}

func fieldNode(_ name: Name, _ type: Type) -> FieldDefinition {
    return FieldDefinition(name: name, type: type)
}

func typeNode(_ name: String) -> NamedType {
    return NamedType(name: nameNode(name))
}

func enumValueNode(_ name: String) -> EnumValueDefinition {
    return EnumValueDefinition(name: nameNode(name))
}

func fieldNodeWithArgs(_ name: Name, _ type: Type, _ args: [InputValueDefinition]) -> FieldDefinition {
    return FieldDefinition(name: name, arguments: args, type: type)
}

func inputValueNode(_ name: Name, _ type: Type, _ defaultValue: Value? = nil) -> InputValueDefinition {
    return InputValueDefinition(name: name, type: type, defaultValue: defaultValue)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleInterface() throws {
        let source = "enum Hello { WO, RLD }"

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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleFieldWithArg() throws {
        let source = "type Hello { world(flag: Boolean): Sting }"

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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleFieldWithArgDefaultValue() throws {
        let source = "type Hello { world(flag: Boolean = true): Sting }"

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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleFieldWithListArg() throws {
        let source = "type Hello { world(things: [String]): Sting }"

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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleFieldWithTwoArgs() throws {
        let source = "type Hello { world(argOne: Boolean, argTwo: Int): Sting }"

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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
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

        XCTAssert(try parse(source: source) == expected)
    }

    func testSimpleInputObjectWithArgs() throws {
        let source = "input Hello { world(foo: Int): String }"
        XCTAssertThrowsError(try parse(source: source))
    }
}

extension SchemaParserTests {
    static var allTests: [(String, (SchemaParserTests) -> () throws -> Void)] {
        return [
            ("testSimpleType", testSimpleType),
            ("testSimpleExtension", testSimpleExtension),
            ("testSimpleNonNullType", testSimpleNonNullType),
            ("testSimpleTypeInheritingInterface", testSimpleTypeInheritingInterface),
            ("testSimpleTypeInheritingMultipleInterfaces", testSimpleTypeInheritingMultipleInterfaces),
            ("testSingleValueEnum", testSingleValueEnum),
            ("testDoubleValueEnum", testDoubleValueEnum),
            ("testSimpleInterface", testSimpleInterface),
            ("testSimpleFieldWithArg", testSimpleFieldWithArg),
            ("testSimpleFieldWithArgDefaultValue", testSimpleFieldWithArgDefaultValue),
            ("testSimpleFieldWithListArg", testSimpleFieldWithListArg),
            ("testSimpleFieldWithTwoArgs", testSimpleFieldWithTwoArgs),
            ("testSimpleUnion", testSimpleUnion),
            ("testUnionTwoTypes", testUnionTwoTypes),
            ("testScalar", testScalar),
            ("testSimpleInputObject", testSimpleInputObject),
            ("testSimpleInputObjectWithArgs", testSimpleInputObjectWithArgs),
        ]
    }
}
