@testable import GraphQL
import XCTest

class ExtendSchemaTests: XCTestCase {
    func schemaChanges(
        _ schema: GraphQLSchema,
        _ extendedSchema: GraphQLSchema
    ) throws -> String {
        let schemaDefinitions = try parse(source: printSchema(schema: schema)).definitions
            .map(print)
        return try parse(source: printSchema(schema: extendedSchema))
            .definitions.map(print)
            .filter { def in !schemaDefinitions.contains(def) }
            .joined(separator: "\n\n")
    }

    func extensionASTNodes(_ extensionASTNodes: [Node]) -> String {
        return extensionASTNodes.map(print).joined(separator: "\n\n")
    }

    func astNode(_ astNode: Node?) throws -> String {
        let astNode = try XCTUnwrap(astNode)
        return print(ast: astNode)
    }

    func testReturnsTheOriginalSchemaWhenThereAreNoTypeDefinitions() throws {
        let schema = try buildSchema(source: "type Query")
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "{ field }")
        )
        XCTAssertEqual(
            ObjectIdentifier(extendedSchema),
            ObjectIdentifier(schema)
        )
    }

    func testCanBeUsedForLimitedExecution() async throws {
        let schema = try buildSchema(source: "type Query")
        let extendAST = try parse(source: """
        extend type Query {
          newField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)
        let result = try await graphql(
            schema: extendedSchema,
            request: "{ newField }",
            rootValue: ["newField": 123]
        )
        XCTAssertEqual(
            result,
            .init(data: ["newField": "123"])
        )
    }

    func testDoNotModifyBuiltInTypesAnDirectives() throws {
        let schema = try buildSchema(source: """
        type Query {
          str: String
          int: Int
          float: Float
          id: ID
          bool: Boolean
        }
        """)
        let extendAST = try parse(source: """
        extend type Query {
          foo: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        // Built-ins are used
        XCTAssertIdentical(
            extendedSchema.getType(name: "Int") as? GraphQLScalarType,
            GraphQLInt
        )
        XCTAssertIdentical(
            extendedSchema.getType(name: "Float") as? GraphQLScalarType,
            GraphQLFloat
        )
        XCTAssertIdentical(
            extendedSchema.getType(name: "String") as? GraphQLScalarType,
            GraphQLString
        )
        XCTAssertIdentical(
            extendedSchema.getType(name: "Boolean") as? GraphQLScalarType,
            GraphQLBoolean
        )
        XCTAssertIdentical(
            extendedSchema.getType(name: "ID") as? GraphQLScalarType,
            GraphQLID
        )

        XCTAssertIdentical(
            extendedSchema.getDirective(name: "include"),
            GraphQLIncludeDirective
        )
        XCTAssertIdentical(
            extendedSchema.getDirective(name: "skip"),
            GraphQLSkipDirective
        )
        XCTAssertIdentical(
            extendedSchema.getDirective(name: "deprecated"),
            GraphQLDeprecatedDirective
        )
        XCTAssertIdentical(
            extendedSchema.getDirective(name: "specifiedBy"),
            GraphQLSpecifiedByDirective
        )
        XCTAssertIdentical(
            extendedSchema.getDirective(name: "oneOf"),
            GraphQLOneOfDirective
        )
    }

    func testPreservesOriginalSchemaConfig() throws {
        let description = "A schema description"
        let extensions: GraphQLSchemaExtensions = ["foo": "bar"]
        let schema = try GraphQLSchema(description: description, extensions: [extensions])

        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "scalar Bar")
        )

        XCTAssertEqual(extendedSchema.description, description)
        XCTAssertEqual(extendedSchema.extensions, [extensions])
    }

    func testExtendsObjectsByAddingNewFields() throws {
        let schema = try buildSchema(source: #"""
          type Query {
            someObject: SomeObject
          }

          type SomeObject implements AnotherInterface & SomeInterface {
            self: SomeObject
            tree: [SomeObject]!
            """Old field description."""
            oldField: String
          }

          interface SomeInterface {
            self: SomeInterface
          }

          interface AnotherInterface {
            self: SomeObject
          }
        """#)
        let extensionSDL = #"""
          extend type SomeObject {
            """New field description."""
            newField(arg: Boolean): String
          }
        """#
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            #"""
            type SomeObject implements AnotherInterface & SomeInterface {
              self: SomeObject
              tree: [SomeObject]!
              """Old field description."""
              oldField: String
              """New field description."""
              newField(arg: Boolean): String
            }
            """#
        )
    }

    func testExtendsScalarsByAddingNewDirectives() throws {
        let schema = try buildSchema(source: """
        type Query {
          someScalar(arg: SomeScalar): SomeScalar
        }

        directive @foo(arg: SomeScalar) on SCALAR

        input FooInput {
          foo: SomeScalar
        }

        scalar SomeScalar
        """)
        let extensionSDL = """
        extend scalar SomeScalar @foo
        """
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )
        let someScalar =
            try XCTUnwrap((extendedSchema.getType(name: "SomeScalar") as? GraphQLScalarType))

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        XCTAssertEqual(extensionASTNodes(someScalar.extensionASTNodes), extensionSDL)
    }

    func testExtendsScalarsByAddingSpecifiedByDirective() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: Foo
        }

        scalar Foo

        directive @foo on SCALAR
        """)
        let extensionSDL = """
        extend scalar Foo @foo

        extend scalar Foo @specifiedBy(url: "https://example.com/foo_spec")
        """

        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )
        let foo = try XCTUnwrap(extendedSchema.getType(name: "Foo") as? GraphQLScalarType)

        XCTAssertEqual(foo.specifiedByURL, "https://example.com/foo_spec")

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        XCTAssertEqual(extensionASTNodes(foo.extensionASTNodes), extensionSDL)
    }

    func testCorrectlyAssignASTNodesToNewAndExtendedTypes() throws {
        let schema = try buildSchema(source: """
          type Query

          scalar SomeScalar
          enum SomeEnum
          union SomeUnion
          input SomeInput
          type SomeObject
          interface SomeInterface

          directive @foo on SCALAR
        """)
        let firstExtensionAST = try parse(source: """
          extend type Query {
            newField(testArg: TestInput): TestEnum
          }

          extend scalar SomeScalar @foo

          extend enum SomeEnum {
            NEW_VALUE
          }

          extend union SomeUnion = SomeObject

          extend input SomeInput {
            newField: String
          }

          extend interface SomeInterface {
            newField: String
          }

          enum TestEnum {
            TEST_VALUE
          }

          input TestInput {
            testInputField: TestEnum
          }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: firstExtensionAST)

        let secondExtensionAST = try parse(source: """
          extend type Query {
            oneMoreNewField: TestUnion
          }

          extend scalar SomeScalar @test

          extend enum SomeEnum {
            ONE_MORE_NEW_VALUE
          }

          extend union SomeUnion = TestType

          extend input SomeInput {
            oneMoreNewField: String
          }

          extend interface SomeInterface {
            oneMoreNewField: String
          }

          union TestUnion = TestType

          interface TestInterface {
            interfaceField: String
          }

          type TestType implements TestInterface {
            interfaceField: String
          }

          directive @test(arg: Int) repeatable on FIELD | SCALAR
        """)
        let extendedTwiceSchema = try extendSchema(
            schema: extendedSchema,
            documentAST: secondExtensionAST
        )

        let extendedInOneGoSchema = try extendSchema(
            schema: schema,
            documentAST: concatAST(documents: [firstExtensionAST, secondExtensionAST])
        )
        XCTAssertEqual(
            printSchema(schema: extendedInOneGoSchema),
            printSchema(schema: extendedTwiceSchema)
        )

        let query = try XCTUnwrap(extendedTwiceSchema.getType(name: "Query") as? GraphQLObjectType)
        let someEnum = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "SomeEnum") as? GraphQLEnumType
        )
        let someUnion = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "SomeUnion") as? GraphQLUnionType
        )
        let someScalar = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "SomeScalar") as? GraphQLScalarType
        )
        let someInput = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "SomeInput") as? GraphQLInputObjectType
        )
        let someInterface = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "SomeInterface") as? GraphQLInterfaceType
        )

        let testInput = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "TestInput") as? GraphQLInputObjectType
        )
        let testEnum = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "TestEnum") as? GraphQLEnumType
        )
        let testUnion = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "TestUnion") as? GraphQLUnionType
        )
        let testType = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "TestType") as? GraphQLObjectType
        )
        let testInterface = try XCTUnwrap(
            extendedTwiceSchema
                .getType(name: "TestInterface") as? GraphQLInterfaceType
        )
        let testDirective = try XCTUnwrap(extendedTwiceSchema.getDirective(name: "test"))

        XCTAssertEqual(testType.extensionASTNodes, [])
        XCTAssertEqual(testEnum.extensionASTNodes, [])
        XCTAssertEqual(testUnion.extensionASTNodes, [])
        XCTAssertEqual(testInput.extensionASTNodes, [])
        XCTAssertEqual(testInterface.extensionASTNodes, [])

        var astNodes: [Definition] = try [
            XCTUnwrap(testInput.astNode),
            XCTUnwrap(testEnum.astNode),
            XCTUnwrap(testUnion.astNode),
            XCTUnwrap(testInterface.astNode),
            XCTUnwrap(testType.astNode),
            XCTUnwrap(testDirective.astNode),
        ]
        astNodes.append(contentsOf: query.extensionASTNodes)
        astNodes.append(contentsOf: someScalar.extensionASTNodes)
        astNodes.append(contentsOf: someEnum.extensionASTNodes)
        astNodes.append(contentsOf: someUnion.extensionASTNodes)
        astNodes.append(contentsOf: someInput.extensionASTNodes)
        astNodes.append(contentsOf: someInterface.extensionASTNodes)
        for def in firstExtensionAST.definitions {
            XCTAssert(astNodes.contains { $0.kind == def.kind && $0.loc == def.loc })
        }
        for def in secondExtensionAST.definitions {
            XCTAssert(astNodes.contains { $0.kind == def.kind && $0.loc == def.loc })
        }

        let newField = try XCTUnwrap(query.getFields()["newField"])
        try XCTAssertEqual(astNode(newField.astNode), "newField(testArg: TestInput): TestEnum")
        try XCTAssertEqual(
            astNode(newField.argConfigMap()["testArg"]?.astNode),
            "testArg: TestInput"
        )
        try XCTAssertEqual(
            astNode(query.getFields()["oneMoreNewField"]?.astNode),
            "oneMoreNewField: TestUnion"
        )

        try XCTAssertEqual(astNode(someEnum.nameLookup["NEW_VALUE"]?.astNode), "NEW_VALUE")
        try XCTAssertEqual(
            astNode(someEnum.nameLookup["ONE_MORE_NEW_VALUE"]?.astNode),
            "ONE_MORE_NEW_VALUE"
        )

        try XCTAssertEqual(astNode(someInput.getFields()["newField"]?.astNode), "newField: String")
        try XCTAssertEqual(
            astNode(someInput.getFields()["oneMoreNewField"]?.astNode),
            "oneMoreNewField: String"
        )
        try XCTAssertEqual(
            astNode(someInterface.getFields()["newField"]?.astNode),
            "newField: String"
        )
        try XCTAssertEqual(
            astNode(someInterface.getFields()["oneMoreNewField"]?.astNode),
            "oneMoreNewField: String"
        )

        try XCTAssertEqual(
            astNode(testInput.getFields()["testInputField"]?.astNode),
            "testInputField: TestEnum"
        )

        try XCTAssertEqual(astNode(testEnum.nameLookup["TEST_VALUE"]?.astNode), "TEST_VALUE")

        try XCTAssertEqual(
            astNode(testInterface.getFields()["interfaceField"]?.astNode),
            "interfaceField: String"
        )
        try XCTAssertEqual(
            astNode(testType.getFields()["interfaceField"]?.astNode),
            "interfaceField: String"
        )

        try XCTAssertEqual(astNode(testDirective.argConfigMap()["arg"]?.astNode), "arg: Int")
    }

    func testBuildsTypesWithDeprecatedFieldsValues() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: """
        type SomeObject {
          deprecatedField: String @deprecated(reason: "not used anymore")
        }

        enum SomeEnum {
          DEPRECATED_VALUE @deprecated(reason: "do not use")
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let someType = try XCTUnwrap(
            extendedSchema
                .getType(name: "SomeObject") as? GraphQLObjectType
        )
        try XCTAssertEqual(
            someType.getFields()["deprecatedField"]?.deprecationReason,
            "not used anymore"
        )

        let someEnum = try XCTUnwrap(extendedSchema.getType(name: "SomeEnum") as? GraphQLEnumType)
        XCTAssertEqual(
            someEnum.nameLookup["DEPRECATED_VALUE"]?.deprecationReason,
            "do not use"
        )
    }

    func testExtendsObjectsWithDeprecatedFields() throws {
        let schema = try buildSchema(source: "type SomeObject")
        let extendAST = try parse(source: """
        extend type SomeObject {
          deprecatedField: String @deprecated(reason: "not used anymore")
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let someType = try XCTUnwrap(
            extendedSchema
                .getType(name: "SomeObject") as? GraphQLObjectType
        )
        try XCTAssertEqual(
            someType.getFields()["deprecatedField"]?.deprecationReason,
            "not used anymore"
        )
    }

    func testExtendsEnumsWithDeprecatedValues() throws {
        let schema = try buildSchema(source: "enum SomeEnum")
        let extendAST = try parse(source: """
        extend enum SomeEnum {
          DEPRECATED_VALUE @deprecated(reason: "do not use")
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let someEnum = try XCTUnwrap(extendedSchema.getType(name: "SomeEnum") as? GraphQLEnumType)
        XCTAssertEqual(
            someEnum.nameLookup["DEPRECATED_VALUE"]?.deprecationReason,
            "do not use"
        )
    }

    func testAddsNewUnusedTypes() throws {
        let schema = try buildSchema(source: """
        type Query {
          dummy: String
        }
        """)
        let extensionSDL = """
        type DummyUnionMember {
          someField: String
        }

        enum UnusedEnum {
          SOME_VALUE
        }

        input UnusedInput {
          someField: String
        }

        interface UnusedInterface {
          someField: String
        }

        type UnusedObject {
          someField: String
        }

        union UnusedUnion = DummyUnionMember
        """
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            extensionSDL
        )
    }

    func testExtendsObjectsByAddingNewFieldsWithArguments() throws {
        let schema = try buildSchema(source: """
        type SomeObject

        type Query {
          someObject: SomeObject
        }
        """)
        let extendAST = try parse(source: """
        input NewInputObj {
          field1: Int
          field2: [Float]
          field3: String!
        }

        extend type SomeObject {
          newField(arg1: String, arg2: NewInputObj!): String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            type SomeObject {
              newField(arg1: String, arg2: NewInputObj!): String
            }

            input NewInputObj {
              field1: Int
              field2: [Float]
              field3: String!
            }
            """
        )
    }

    func testExtendsObjectsByAddingNewFieldsWithExistingTypes() throws {
        let schema = try buildSchema(source: """
        type Query {
          someObject: SomeObject
        }

        type SomeObject
        enum SomeEnum { VALUE }
        """)
        let extendAST = try parse(source: """
          extend type SomeObject {
            newField(arg1: SomeEnum!): SomeEnum
          }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            type SomeObject {
              newField(arg1: SomeEnum!): SomeEnum
            }
            """
        )
    }

    func testExtendsObjectsByAddingImplementedInterfaces() throws {
        let schema = try buildSchema(source: """
        type Query {
          someObject: SomeObject
        }

        type SomeObject {
          foo: String
        }

        interface SomeInterface {
          foo: String
        }
        """)
        let extendAST = try parse(source: """
        extend type SomeObject implements SomeInterface
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            type SomeObject implements SomeInterface {
              foo: String
            }
            """
        )
    }

    func testExtendsObjectsByIncludingNewTypes() throws {
        let schema = try buildSchema(source: """
        type Query {
          someObject: SomeObject
        }

        type SomeObject {
          oldField: String
        }
        """)
        let newTypesSDL = """
        enum NewEnum {
          VALUE
        }

        interface NewInterface {
          baz: String
        }

        type NewObject implements NewInterface {
          baz: String
        }

        scalar NewScalar

        union NewUnion = NewObject
        """
        let extendAST = try parse(source: """
        \(newTypesSDL)
        extend type SomeObject {
          newObject: NewObject
          newInterface: NewInterface
          newUnion: NewUnion
          newScalar: NewScalar
          newEnum: NewEnum
          newTree: [SomeObject]!
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            type SomeObject {
              oldField: String
              newObject: NewObject
              newInterface: NewInterface
              newUnion: NewUnion
              newScalar: NewScalar
              newEnum: NewEnum
              newTree: [SomeObject]!
            }

            \(newTypesSDL)
            """
        )
    }

    func testExtendsObjectsByAddingImplementedNewInterfaces() throws {
        let schema = try buildSchema(source: """
        type Query {
          someObject: SomeObject
        }

        type SomeObject implements OldInterface {
          oldField: String
        }

        interface OldInterface {
          oldField: String
        }
        """)
        let extendAST = try parse(source: """
        extend type SomeObject implements NewInterface {
          newField: String
        }

        interface NewInterface {
          newField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            type SomeObject implements OldInterface & NewInterface {
              oldField: String
              newField: String
            }

            interface NewInterface {
              newField: String
            }
            """
        )
    }

    func testExtendsDifferentTypesMultipleTimes() throws {
        let schema = try buildSchema(source: """
        type Query {
          someScalar: SomeScalar
          someObject(someInput: SomeInput): SomeObject
          someInterface: SomeInterface
          someEnum: SomeEnum
          someUnion: SomeUnion
        }

        scalar SomeScalar

        type SomeObject implements SomeInterface {
          oldField: String
        }

        interface SomeInterface {
          oldField: String
        }

        enum SomeEnum {
          OLD_VALUE
        }

        union SomeUnion = SomeObject

        input SomeInput {
          oldField: String
        }
        """)
        let newTypesSDL = """
        scalar NewScalar

        scalar AnotherNewScalar

        type NewObject {
          foo: String
        }

        type AnotherNewObject {
          foo: String
        }

        interface NewInterface {
          newField: String
        }

        interface AnotherNewInterface {
          anotherNewField: String
        }
        """
        let schemaWithNewTypes = try extendSchema(
            schema: schema,
            documentAST: parse(source: newTypesSDL)
        )
        try XCTAssertEqual(
            schemaChanges(schema, schemaWithNewTypes),
            newTypesSDL
        )

        let extendAST = try parse(source: """
        extend scalar SomeScalar @specifiedBy(url: "http://example.com/foo_spec")

        extend type SomeObject implements NewInterface {
          newField: String
        }

        extend type SomeObject implements AnotherNewInterface {
          anotherNewField: String
        }

        extend enum SomeEnum {
          NEW_VALUE
        }

        extend enum SomeEnum {
          ANOTHER_NEW_VALUE
        }

         extend union SomeUnion = NewObject

        extend union SomeUnion = AnotherNewObject

        extend input SomeInput {
          newField: String
        }

        extend input SomeInput {
          anotherNewField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schemaWithNewTypes, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            scalar SomeScalar @specifiedBy(url: "http://example.com/foo_spec")

            type SomeObject implements SomeInterface & NewInterface & AnotherNewInterface {
              oldField: String
              newField: String
              anotherNewField: String
            }

            enum SomeEnum {
              OLD_VALUE
              NEW_VALUE
              ANOTHER_NEW_VALUE
            }

            union SomeUnion = SomeObject | NewObject | AnotherNewObject

            input SomeInput {
              oldField: String
              newField: String
              anotherNewField: String
            }

            \(newTypesSDL)
            """
        )
    }

    func testExtendsInterfacesByAddingNewFields() throws {
        let schema = try buildSchema(source: """
        interface SomeInterface {
          oldField: String
        }

        interface AnotherInterface implements SomeInterface {
          oldField: String
        }

        type SomeObject implements SomeInterface & AnotherInterface {
          oldField: String
        }

        type Query {
          someInterface: SomeInterface
        }
        """)
        let extendAST = try parse(source: """
        extend interface SomeInterface {
          newField: String
        }

        extend interface AnotherInterface {
          newField: String
        }

        extend type SomeObject {
          newField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            interface SomeInterface {
              oldField: String
              newField: String
            }

            interface AnotherInterface implements SomeInterface {
              oldField: String
              newField: String
            }

            type SomeObject implements SomeInterface & AnotherInterface {
              oldField: String
              newField: String
            }
            """
        )
    }

    func testExtendsInterfacesByAddingNewImplementedInterfaces() throws {
        let schema = try buildSchema(source: """
        interface SomeInterface {
          oldField: String
        }

        interface AnotherInterface implements SomeInterface {
          oldField: String
        }

        type SomeObject implements SomeInterface & AnotherInterface {
          oldField: String
        }

        type Query {
          someInterface: SomeInterface
        }
        """)
        let extendAST = try parse(source: """
        interface NewInterface {
          newField: String
        }

        extend interface AnotherInterface implements NewInterface {
          newField: String
        }

        extend type SomeObject implements NewInterface {
          newField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            interface AnotherInterface implements SomeInterface & NewInterface {
              oldField: String
              newField: String
            }

            type SomeObject implements SomeInterface & AnotherInterface & NewInterface {
              oldField: String
              newField: String
            }

            interface NewInterface {
              newField: String
            }
            """
        )
    }

    func testAllowsExtensionOfInterfaceWithMissingObjectFields() throws {
        let schema = try buildSchema(source: """
        type Query {
          someInterface: SomeInterface
        }

        type SomeObject implements SomeInterface {
          oldField: SomeInterface
        }

        interface SomeInterface {
          oldField: SomeInterface
        }
        """)
        let extendAST = try parse(source: """
        extend interface SomeInterface {
          newField: String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertGreaterThan(validateSchema(schema: extendedSchema).count, 0)
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            interface SomeInterface {
              oldField: SomeInterface
              newField: String
            }
            """
        )
    }

    func testExtendsInterfacesMultipleTimes() throws {
        let schema = try buildSchema(source: """
        type Query {
          someInterface: SomeInterface
        }

        interface SomeInterface {
          some: SomeInterface
        }
        """)
        let extendAST = try parse(source: """
        extend interface SomeInterface {
          newFieldA: Int
        }

        extend interface SomeInterface {
          newFieldB(test: Boolean): String
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            """
            interface SomeInterface {
              some: SomeInterface
              newFieldA: Int
              newFieldB(test: Boolean): String
            }
            """
        )
    }

    func testMayExtendMutationsAndSubscriptions() throws {
        let mutationSchema = try buildSchema(source: """
        type Query {
          queryField: String
        }

        type Mutation {
          mutationField: String
        }

        type Subscription {
          subscriptionField: String
        }
        """)
        let ast = try parse(source: """
        extend type Query {
          newQueryField: Int
        }

        extend type Mutation {
          newMutationField: Int
        }

        extend type Subscription {
          newSubscriptionField: Int
        }
        """)
        let originalPrint = printSchema(schema: mutationSchema)
        let extendedSchema = try extendSchema(schema: mutationSchema, documentAST: ast)

        XCTAssertEqual(printSchema(schema: mutationSchema), originalPrint)
        XCTAssertEqual(
            printSchema(schema: extendedSchema),
            """
            type Query {
              queryField: String
              newQueryField: Int
            }

            type Mutation {
              mutationField: String
              newMutationField: Int
            }

            type Subscription {
              subscriptionField: String
              newSubscriptionField: Int
            }
            """
        )
    }

    func testMayExtendDirectivesWithNewDirective() throws {
        let schema = try buildSchema(source: """
        type Query {
          foo: String
        }
        """)
        let extensionSDL = #"""
        """New directive."""
        directive @new(enable: Boolean!, tag: String) repeatable on QUERY | FIELD
        """#
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        try XCTAssertEqual(validateSchema(schema: extendedSchema), [])
        try XCTAssertEqual(
            schemaChanges(schema, extendedSchema),
            extensionSDL
        )
    }

    func testRejectsInvalidSDL() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: "extend schema @unknown")

        try XCTAssertThrowsError(
            extendSchema(schema: schema, documentAST: extendAST),
            "Unknown directive \"@unknown\"."
        )
    }

    func testAllowsToDisableSDLValidation() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: "extend schema @unknown")

        _ = try extendSchema(schema: schema, documentAST: extendAST, assumeValid: true)
        _ = try extendSchema(schema: schema, documentAST: extendAST, assumeValidSDL: true)
    }

    func testThrowsOnUnknownTypes() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: """
        type Query {
          unknown: UnknownType
        }
        """)

        try XCTAssertThrowsError(
            extendSchema(schema: schema, documentAST: extendAST, assumeValidSDL: true),
            "Unknown type: \"UnknownType\"."
        )
    }

    func testDoesNotAllowReplacingADefaultDirective() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: """
        directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD
        """)

        try XCTAssertThrowsError(
            extendSchema(schema: schema, documentAST: extendAST),
            "Directive \"@include\" already exists in the schema. It cannot be redefined."
        )
    }

    func testDoesNotAllowReplacingAnExistingEnumValue() throws {
        let schema = try buildSchema(source: """
        enum SomeEnum {
          ONE
        }
        """)
        let extendAST = try parse(source: """
        extend enum SomeEnum {
          ONE
        }
        """)

        try XCTAssertThrowsError(
            extendSchema(schema: schema, documentAST: extendAST),
            "Enum value \"SomeEnum.ONE\" already exists in the schema. It cannot also be defined in this type extension."
        )
    }

    // MARK: can add additional root operation types

    func testDoesNotAutomaticallyIncludeCommonRootTypeNames() throws {
        let schema = try GraphQLSchema()
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "type Mutation")
        )

        XCTAssertNotNil(extendedSchema.getType(name: "Mutation"))
        XCTAssertNil(extendedSchema.mutationType)
    }

    func testAddsSchemaDefinitionMissingInTheOriginalSchema() throws {
        let schema = try buildSchema(source: """
        directive @foo on SCHEMA
        type Foo
        """)
        XCTAssertNil(schema.queryType)

        let extensionSDL = """
        schema @foo {
          query: Foo
        }
        """
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        let queryType = extendedSchema.queryType
        XCTAssertEqual(queryType?.name, "Foo")
        try XCTAssertEqual(astNode(extendedSchema.astNode), extensionSDL)
    }

    func testAddsNewRootTypesViaSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query
        type MutationRoot
        """)
        let extensionSDL = """
        extend schema {
          mutation: MutationRoot
        }
        """
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        let mutationType = extendedSchema.mutationType
        XCTAssertEqual(mutationType?.name, "MutationRoot")
        XCTAssertEqual(extensionASTNodes(extendedSchema.extensionASTNodes), extensionSDL)
    }

    func testAddsDirectiveViaSchemaExtension() throws {
        let schema = try buildSchema(source: """
        type Query

        directive @foo on SCHEMA
        """)
        let extensionSDL = """
        extend schema @foo
        """
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: extensionSDL)
        )

        XCTAssertEqual(extensionASTNodes(extendedSchema.extensionASTNodes), extensionSDL)
    }

    func testAddsMultipleNewRootTypesViaSchemaExtension() throws {
        let schema = try buildSchema(source: "type Query")
        let extendAST = try parse(source: """
        extend schema {
          mutation: Mutation
          subscription: Subscription
        }

        type Mutation
        type Subscription
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let mutationType = extendedSchema.mutationType
        XCTAssertEqual(mutationType?.name, "Mutation")

        let subscriptionType = extendedSchema.subscriptionType
        XCTAssertEqual(subscriptionType?.name, "Subscription")
    }

    func testAppliesMultipleSchemaExtensions() throws {
        let schema = try buildSchema(source: "type Query")
        let extendAST = try parse(source: """
        extend schema {
          mutation: Mutation
        }
        type Mutation

        extend schema {
          subscription: Subscription
        }
        type Subscription
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let mutationType = extendedSchema.mutationType
        XCTAssertEqual(mutationType?.name, "Mutation")

        let subscriptionType = extendedSchema.subscriptionType
        XCTAssertEqual(subscriptionType?.name, "Subscription")
    }

    func testSchemaExtensionASTAreAvailableFromSchemaObject() throws {
        let schema = try buildSchema(source: """
        type Query

        directive @foo on SCHEMA
        """)
        let extendAST = try parse(source: """
        extend schema {
          mutation: Mutation
        }
        type Mutation

        extend schema {
          subscription: Subscription
        }
        type Subscription
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let secondExtendAST = try parse(source: "extend schema @foo")
        let extendedTwiceSchema = try extendSchema(
            schema: extendedSchema,
            documentAST: secondExtendAST
        )

        XCTAssertEqual(
            extensionASTNodes(extendedTwiceSchema.extensionASTNodes),
            """
            extend schema {
              mutation: Mutation
            }

            extend schema {
              subscription: Subscription
            }

            extend schema @foo
            """
        )
    }
}
