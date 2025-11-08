@testable import GraphQL
import Testing

@Suite struct ExtendSchemaTests {
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

    func astNode(_ astNodeOptional: Node?) throws -> String {
        let astNode = try #require(astNodeOptional)
        return print(ast: astNode)
    }

    @Test func returnsTheOriginalSchemaWhenThereAreNoTypeDefinitions() throws {
        let schema = try buildSchema(source: "type Query")
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "{ field }")
        )
        #expect(
            ObjectIdentifier(extendedSchema) ==
                ObjectIdentifier(schema)
        )
    }

    @Test func canBeUsedForLimitedExecution() async throws {
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
        #expect(
            result ==
                .init(data: ["newField": "123"])
        )
    }

    @Test func doNotModifyBuiltInTypesAnDirectives() throws {
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
        #expect(
            extendedSchema.getType(name: "Int") as? GraphQLScalarType ===
                GraphQLInt
        )
        #expect(
            extendedSchema.getType(name: "Float") as? GraphQLScalarType ===
                GraphQLFloat
        )
        #expect(
            extendedSchema.getType(name: "String") as? GraphQLScalarType ===
                GraphQLString
        )
        #expect(
            extendedSchema.getType(name: "Boolean") as? GraphQLScalarType ===
                GraphQLBoolean
        )
        #expect(
            extendedSchema.getType(name: "ID") as? GraphQLScalarType ===
                GraphQLID
        )

        #expect(
            extendedSchema.getDirective(name: "include") ===
                GraphQLIncludeDirective
        )
        #expect(
            extendedSchema.getDirective(name: "skip") ===
                GraphQLSkipDirective
        )
        #expect(
            extendedSchema.getDirective(name: "deprecated") ===
                GraphQLDeprecatedDirective
        )
        #expect(
            extendedSchema.getDirective(name: "specifiedBy") ===
                GraphQLSpecifiedByDirective
        )
        #expect(
            extendedSchema.getDirective(name: "oneOf") ===
                GraphQLOneOfDirective
        )
    }

    @Test func preservesOriginalSchemaConfig() throws {
        let description = "A schema description"
        let extensions: GraphQLSchemaExtensions = ["foo": "bar"]
        let schema = try GraphQLSchema(description: description, extensions: [extensions])

        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "scalar Bar")
        )

        #expect(extendedSchema.description == description)
        #expect(extendedSchema.extensions == [extensions])
    }

    @Test func extendsObjectsByAddingNewFields() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) ==
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

    @Test func extendsScalarsByAddingNewDirectives() throws {
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
            try #require((extendedSchema.getType(name: "SomeScalar") as? GraphQLScalarType))

        try #expect(validateSchema(schema: extendedSchema) == [])
        #expect(extensionASTNodes(someScalar.extensionASTNodes) == extensionSDL)
    }

    @Test func extendsScalarsByAddingSpecifiedByDirective() throws {
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
        let foo = try #require(extendedSchema.getType(name: "Foo") as? GraphQLScalarType)

        #expect(foo.specifiedByURL == "https://example.com/foo_spec")

        try #expect(validateSchema(schema: extendedSchema) == [])
        #expect(extensionASTNodes(foo.extensionASTNodes) == extensionSDL)
    }

    @Test func correctlyAssignASTNodesToNewAndExtendedTypes() throws {
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
        #expect(
            printSchema(schema: extendedInOneGoSchema) ==
                printSchema(schema: extendedTwiceSchema)
        )

        let query = try #require(extendedTwiceSchema.getType(name: "Query") as? GraphQLObjectType)
        let someEnum = try #require(
            extendedTwiceSchema
                .getType(name: "SomeEnum") as? GraphQLEnumType
        )
        let someUnion = try #require(
            extendedTwiceSchema
                .getType(name: "SomeUnion") as? GraphQLUnionType
        )
        let someScalar = try #require(
            extendedTwiceSchema
                .getType(name: "SomeScalar") as? GraphQLScalarType
        )
        let someInput = try #require(
            extendedTwiceSchema
                .getType(name: "SomeInput") as? GraphQLInputObjectType
        )
        let someInterface = try #require(
            extendedTwiceSchema
                .getType(name: "SomeInterface") as? GraphQLInterfaceType
        )

        let testInput = try #require(
            extendedTwiceSchema
                .getType(name: "TestInput") as? GraphQLInputObjectType
        )
        let testEnum = try #require(
            extendedTwiceSchema
                .getType(name: "TestEnum") as? GraphQLEnumType
        )
        let testUnion = try #require(
            extendedTwiceSchema
                .getType(name: "TestUnion") as? GraphQLUnionType
        )
        let testType = try #require(
            extendedTwiceSchema
                .getType(name: "TestType") as? GraphQLObjectType
        )
        let testInterface = try #require(
            extendedTwiceSchema
                .getType(name: "TestInterface") as? GraphQLInterfaceType
        )
        let testDirective = try #require(extendedTwiceSchema.getDirective(name: "test"))

        #expect(testType.extensionASTNodes == [])
        #expect(testEnum.extensionASTNodes == [])
        #expect(testUnion.extensionASTNodes == [])
        #expect(testInput.extensionASTNodes == [])
        #expect(testInterface.extensionASTNodes == [])

        var astNodes: [Definition] = try [
            #require(testInput.astNode),
            #require(testEnum.astNode),
            #require(testUnion.astNode),
            #require(testInterface.astNode),
            #require(testType.astNode),
            #require(testDirective.astNode),
        ]
        astNodes.append(contentsOf: query.extensionASTNodes)
        astNodes.append(contentsOf: someScalar.extensionASTNodes)
        astNodes.append(contentsOf: someEnum.extensionASTNodes)
        astNodes.append(contentsOf: someUnion.extensionASTNodes)
        astNodes.append(contentsOf: someInput.extensionASTNodes)
        astNodes.append(contentsOf: someInterface.extensionASTNodes)
        for def in firstExtensionAST.definitions {
            #expect(astNodes.contains { $0.kind == def.kind && $0.loc == def.loc })
        }
        for def in secondExtensionAST.definitions {
            #expect(astNodes.contains { $0.kind == def.kind && $0.loc == def.loc })
        }

        let newField = try #require(query.getFields()["newField"])
        try #expect(astNode(newField.astNode) == "newField(testArg: TestInput): TestEnum")
        try #expect(
            astNode(newField.argConfigMap()["testArg"]?.astNode) ==
                "testArg: TestInput"
        )
        try #expect(
            astNode(query.getFields()["oneMoreNewField"]?.astNode) ==
                "oneMoreNewField: TestUnion"
        )

        try #expect(astNode(someEnum.nameLookup["NEW_VALUE"]?.astNode) == "NEW_VALUE")
        try #expect(
            astNode(someEnum.nameLookup["ONE_MORE_NEW_VALUE"]?.astNode) ==
                "ONE_MORE_NEW_VALUE"
        )

        try #expect(astNode(someInput.getFields()["newField"]?.astNode) == "newField: String")
        try #expect(
            astNode(someInput.getFields()["oneMoreNewField"]?.astNode) ==
                "oneMoreNewField: String"
        )
        try #expect(
            astNode(someInterface.getFields()["newField"]?.astNode) ==
                "newField: String"
        )
        try #expect(
            astNode(someInterface.getFields()["oneMoreNewField"]?.astNode) ==
                "oneMoreNewField: String"
        )

        try #expect(
            astNode(testInput.getFields()["testInputField"]?.astNode) ==
                "testInputField: TestEnum"
        )

        try #expect(astNode(testEnum.nameLookup["TEST_VALUE"]?.astNode) == "TEST_VALUE")

        try #expect(
            astNode(testInterface.getFields()["interfaceField"]?.astNode) ==
                "interfaceField: String"
        )
        try #expect(
            astNode(testType.getFields()["interfaceField"]?.astNode) ==
                "interfaceField: String"
        )

        try #expect(astNode(testDirective.argConfigMap()["arg"]?.astNode) == "arg: Int")
    }

    @Test func buildsTypesWithDeprecatedFieldsValues() throws {
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

        let someType = try #require(
            extendedSchema
                .getType(name: "SomeObject") as? GraphQLObjectType
        )
        try #expect(
            someType.getFields()["deprecatedField"]?.deprecationReason ==
                "not used anymore"
        )

        let someEnum = try #require(extendedSchema.getType(name: "SomeEnum") as? GraphQLEnumType)
        #expect(
            someEnum.nameLookup["DEPRECATED_VALUE"]?.deprecationReason ==
                "do not use"
        )
    }

    @Test func extendsObjectsWithDeprecatedFields() throws {
        let schema = try buildSchema(source: "type SomeObject")
        let extendAST = try parse(source: """
        extend type SomeObject {
          deprecatedField: String @deprecated(reason: "not used anymore")
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let someType = try #require(
            extendedSchema
                .getType(name: "SomeObject") as? GraphQLObjectType
        )
        try #expect(
            someType.getFields()["deprecatedField"]?.deprecationReason ==
                "not used anymore"
        )
    }

    @Test func extendsEnumsWithDeprecatedValues() throws {
        let schema = try buildSchema(source: "enum SomeEnum")
        let extendAST = try parse(source: """
        extend enum SomeEnum {
          DEPRECATED_VALUE @deprecated(reason: "do not use")
        }
        """)
        let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)

        let someEnum = try #require(extendedSchema.getType(name: "SomeEnum") as? GraphQLEnumType)
        #expect(
            someEnum.nameLookup["DEPRECATED_VALUE"]?.deprecationReason ==
                "do not use"
        )
    }

    @Test func addsNewUnusedTypes() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) ==
                extensionSDL
        )
    }

    @Test func extendsObjectsByAddingNewFieldsWithArguments() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func extendsObjectsByAddingNewFieldsWithExistingTypes() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
            type SomeObject {
              newField(arg1: SomeEnum!): SomeEnum
            }
            """
        )
    }

    @Test func extendsObjectsByAddingImplementedInterfaces() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
            type SomeObject implements SomeInterface {
              foo: String
            }
            """
        )
    }

    @Test func extendsObjectsByIncludingNewTypes() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func extendsObjectsByAddingImplementedNewInterfaces() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func extendsDifferentTypesMultipleTimes() throws {
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
        try #expect(
            schemaChanges(schema, schemaWithNewTypes) ==
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func extendsInterfacesByAddingNewFields() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func extendsInterfacesByAddingNewImplementedInterfaces() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
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

    @Test func allowsExtensionOfInterfaceWithMissingObjectFields() throws {
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

        try #expect(validateSchema(schema: extendedSchema).count > 0)
        try #expect(
            schemaChanges(schema, extendedSchema) == """
            interface SomeInterface {
              oldField: SomeInterface
              newField: String
            }
            """
        )
    }

    @Test func extendsInterfacesMultipleTimes() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) == """
            interface SomeInterface {
              some: SomeInterface
              newFieldA: Int
              newFieldB(test: Boolean): String
            }
            """
        )
    }

    @Test func mayExtendMutationsAndSubscriptions() throws {
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

        #expect(printSchema(schema: mutationSchema) == originalPrint)
        #expect(
            printSchema(schema: extendedSchema) == """
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

    @Test func mayExtendDirectivesWithNewDirective() throws {
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

        try #expect(validateSchema(schema: extendedSchema) == [])
        try #expect(
            schemaChanges(schema, extendedSchema) ==
                extensionSDL
        )
    }

    @Test func rejectsInvalidSDL() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: "extend schema @unknown")

        #expect(
            throws: (any Error).self,
            "Unknown directive \"@unknown\"."
        ) {
            try extendSchema(schema: schema, documentAST: extendAST)
        }
    }

    @Test func allowsToDisableSDLValidation() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: "extend schema @unknown")

        _ = try extendSchema(schema: schema, documentAST: extendAST, assumeValid: true)
        _ = try extendSchema(schema: schema, documentAST: extendAST, assumeValidSDL: true)
    }

    @Test func throwsOnUnknownTypes() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: """
        type Query {
          unknown: UnknownType
        }
        """)

        #expect(
            throws: (any Error).self,
            "Unknown type: \"UnknownType\"."
        ) {
            try extendSchema(schema: schema, documentAST: extendAST, assumeValidSDL: true)
        }
    }

    @Test func doesNotAllowReplacingADefaultDirective() throws {
        let schema = try GraphQLSchema()
        let extendAST = try parse(source: """
        directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD
        """)

        #expect(
            throws: (any Error).self,
            "Directive \"@include\" already exists in the schema. It cannot be redefined."
        ) {
            try extendSchema(schema: schema, documentAST: extendAST)
        }
    }

    @Test func doesNotAllowReplacingAnExistingEnumValue() throws {
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

        #expect(
            throws: (any Error).self,
            "Enum value \"SomeEnum.ONE\" already exists in the schema. It cannot also be defined in this type extension."
        ) {
            try extendSchema(schema: schema, documentAST: extendAST)
        }
    }

    // MARK: can add additional root operation types

    @Test func doesNotAutomaticallyIncludeCommonRootTypeNames() throws {
        let schema = try GraphQLSchema()
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "type Mutation")
        )

        #expect(extendedSchema.getType(name: "Mutation") != nil)
        #expect(extendedSchema.mutationType == nil)
    }

    @Test func addsSchemaDefinitionMissingInTheOriginalSchema() throws {
        let schema = try buildSchema(source: """
        directive @foo on SCHEMA
        type Foo
        """)
        #expect(schema.queryType == nil)

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
        #expect(queryType?.name == "Foo")
        try #expect(astNode(extendedSchema.astNode) == extensionSDL)
    }

    @Test func addsNewRootTypesViaSchemaExtension() throws {
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
        #expect(mutationType?.name == "MutationRoot")
        #expect(extensionASTNodes(extendedSchema.extensionASTNodes) == extensionSDL)
    }

    @Test func addsDirectiveViaSchemaExtension() throws {
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

        #expect(extensionASTNodes(extendedSchema.extensionASTNodes) == extensionSDL)
    }

    @Test func addsMultipleNewRootTypesViaSchemaExtension() throws {
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
        #expect(mutationType?.name == "Mutation")

        let subscriptionType = extendedSchema.subscriptionType
        #expect(subscriptionType?.name == "Subscription")
    }

    @Test func appliesMultipleSchemaExtensions() throws {
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
        #expect(mutationType?.name == "Mutation")

        let subscriptionType = extendedSchema.subscriptionType
        #expect(subscriptionType?.name == "Subscription")
    }

    @Test func schemaExtensionASTAreAvailableFromSchemaObject() throws {
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

        #expect(
            extensionASTNodes(extendedTwiceSchema.extensionASTNodes) == """
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
