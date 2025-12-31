@testable import GraphQL
import Testing

@Suite struct BuildASTSchemaTests {
    /**
     * This function does a full cycle of going from a string with the contents of
     * the SDL, parsed in a schema AST, materializing that schema AST into an
     * in-memory GraphQLSchema, and then finally printing that object into the SDL
     */
    func cycleSDL(sdl: String) throws -> String {
        return try printSchema(schema: buildSchema(source: sdl))
    }

    @Test func canUseBuiltSchemaForLimitedExecution() async throws {
        let schema = try buildASTSchema(
            documentAST: parse(
                source: """
                type Query {
                  str: String
                }
                """
            )
        )

        let result = try await graphql(
            schema: schema,
            request: "{ str }",
            rootValue: ["str": 123]
        )

        #expect(
            result == GraphQLResult(data: [
                "str": "123",
            ])
        )
    }

    // Closures are invalid Map keys in Swift.
//    @Test func canBuildASchemaDirectlyFromTheSource() throws {
//        let schema = try buildASTSchema(
//            documentAST: try parse(
//                source: """
//                type Query {
//                  add(x: Int, y: Int): Int
//                }
//                """
//            )
//        )
//
//        let result = try await graphql(
//            schema: schema,
//            request: "{ add(x: 34, y: 55) }",
//            rootValue: [
//                "add": { (x: Int, y: Int) in
//                    return x + y
//                }
//            ]
//        )
//
//        #expect(
//            result ==
//            GraphQLResult(data: [
//                "add": 89
//            ])
//        )
//    }

    @Test func ignoresNonTypeSystemDefinitions() throws {
        let sdl = """
        type Query {
          str: String
        }

        fragment SomeFragment on Query {
          str
        }
        """

        #expect(throws: Never.self) { try buildSchema(source: sdl) }
    }

    @Test func matchOrderOfDefaultTypesAndDirectives() throws {
        let schema = try GraphQLSchema()
        let sdlSchema = try buildASTSchema(documentAST: .init(definitions: []))

        #expect(sdlSchema.directives.map { $0.name } == schema.directives.map { $0.name })
        #expect(
            sdlSchema.typeMap.mapValues { $0.name } ==
                schema.typeMap.mapValues { $0.name }
        )
    }

    @Test func emptyType() throws {
        let sdl = """
        type EmptyType
        """

        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleType() throws {
        let sdl = """
        type Query {
          str: String
          int: Int
          float: Float
          id: ID
          bool: Boolean
        }
        """

        try #expect(cycleSDL(sdl: sdl) == sdl)

        let schema = try buildSchema(source: sdl)
        // Built-ins are used
        #expect(
            schema.getType(
                name: "Int"
            ) as? GraphQLScalarType === GraphQLInt
        )
        #expect(
            schema.getType(
                name: "Float"
            ) as? GraphQLScalarType == GraphQLFloat
        )
        #expect(
            schema.getType(
                name: "String"
            ) as? GraphQLScalarType == GraphQLString
        )
        #expect(
            schema.getType(
                name: "Boolean"
            ) as? GraphQLScalarType == GraphQLBoolean
        )
        #expect(
            schema.getType(
                name: "ID"
            ) as? GraphQLScalarType == GraphQLID
        )
    }

    @Test func includeStandardTypeOnlyIfItIsUsed() throws {
        let schema = try buildSchema(source: "type Query")

        // String and Boolean are always included through introspection types
        #expect(schema.getType(name: "Int") == nil)
        #expect(schema.getType(name: "Float") == nil)
        #expect(schema.getType(name: "ID") == nil)
    }

    @Test func withDirectives() throws {
        let sdl = """
        directive @foo(arg: Int) on FIELD

        directive @repeatableFoo(arg: Int) repeatable on FIELD
        """

        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func supportsDescriptions() throws {
        let sdl = #"""
        """Do you agree that this is the most creative schema ever?"""
        schema {
          query: Query
        }

        """This is a directive"""
        directive @foo(
          """It has an argument"""
          arg: Int
        ) on FIELD

        """Who knows what inside this scalar?"""
        scalar MysteryScalar

        """This is a input object type"""
        input FooInput {
          """It has a field"""
          field: Int
        }

        """This is a interface type"""
        interface Energy {
          """It also has a field"""
          str: String
        }

        """There is nothing inside!"""
        union BlackHole

        """With an enum"""
        enum Color {
          RED

          """Not a creative color"""
          GREEN
          BLUE
        }

        """What a great type"""
        type Query {
          """And a field to boot"""
          str: String
        }
        """#

        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func maintainsIncludeSkipAndSpecifiedBy() throws {
        let schema = try buildSchema(source: "type Query")

        #expect(schema.directives.count == 5)
        #expect(
            schema.getDirective(
                name: GraphQLSkipDirective.name
            ) === GraphQLSkipDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLIncludeDirective.name
            ) === GraphQLIncludeDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLDeprecatedDirective.name
            ) === GraphQLDeprecatedDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLSpecifiedByDirective.name
            ) === GraphQLSpecifiedByDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLOneOfDirective.name
            ) === GraphQLOneOfDirective
        )
    }

    @Test func overridingDirectivesExcludesSpecified() throws {
        let schema = try buildSchema(source: """
        directive @skip on FIELD
        directive @include on FIELD
        directive @deprecated on FIELD_DEFINITION
        directive @specifiedBy on FIELD_DEFINITION
        directive @oneOf on OBJECT
        """)

        #expect(schema.directives.count == 5)
        #expect(
            schema.getDirective(
                name: GraphQLSkipDirective.name
            ) !== GraphQLSkipDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLIncludeDirective.name
            ) !== GraphQLIncludeDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLDeprecatedDirective.name
            ) !== GraphQLDeprecatedDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLSpecifiedByDirective.name
            ) !== GraphQLSpecifiedByDirective
        )
        #expect(
            schema.getDirective(
                name: GraphQLOneOfDirective.name
            ) !== GraphQLOneOfDirective
        )
    }

    @Test func addingDirectivesMaintainsIncludeSkipDeprecatedSpecifiedByAndOneOf() throws {
        let schema = try buildSchema(source: """
        directive @foo(arg: Int) on FIELD
        """)

        #expect(schema.directives.count == 6)
        #expect(schema.getDirective(name: GraphQLSkipDirective.name) != nil)
        #expect(schema.getDirective(name: GraphQLIncludeDirective.name) != nil)
        #expect(schema.getDirective(name: GraphQLDeprecatedDirective.name) != nil)
        #expect(schema.getDirective(name: GraphQLSpecifiedByDirective.name) != nil)
        #expect(schema.getDirective(name: GraphQLOneOfDirective.name) != nil)
    }

    @Test func typeModifiers() throws {
        let sdl = """
        type Query {
          nonNullStr: String!
          listOfStrings: [String]
          listOfNonNullStrings: [String!]
          nonNullListOfStrings: [String]!
          nonNullListOfNonNullStrings: [String!]!
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func recursiveType() throws {
        let sdl = """
        type Query {
          str: String
          recurse: Query
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func twoTypesCircular() throws {
        let sdl = """
        type TypeOne {
          str: String
          typeTwo: TypeTwo
        }

        type TypeTwo {
          str: String
          typeOne: TypeOne
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func singleArgumentField() throws {
        let sdl = """
        type Query {
          str(int: Int): String
          floatToStr(float: Float): String
          idToStr(id: ID): String
          booleanToStr(bool: Boolean): String
          strToStr(bool: String): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleTypeWithMultipleArguments() throws {
        let sdl = """
        type Query {
          str(int: Int, bool: Boolean): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func emptyInterface() throws {
        let sdl = """
        interface EmptyInterface
        """
        let definition = try #require(
            parse(source: sdl)
                .definitions[0] as? InterfaceTypeDefinition
        )
        #expect(definition.interfaces == [])
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleTypeWithInterface() throws {
        let sdl = """
        type Query implements WorldInterface {
          str: String
        }

        interface WorldInterface {
          str: String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleInterfaceHierarchy() throws {
        let sdl = """
        interface Child implements Parent {
          str: String
        }

        type Hello implements Parent & Child {
          str: String
        }

        interface Parent {
          str: String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func emptyEnum() throws {
        let sdl = """
        enum EmptyEnum
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleOutputEnum() throws {
        let sdl = """
        enum Hello {
          WORLD
        }

        type Query {
          hello: Hello
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleInputEnum() throws {
        let sdl = """
        enum Hello {
          WORLD
        }

        type Query {
          str(hello: Hello): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func multipleValueEnum() throws {
        let sdl = """
        enum Hello {
          WO
          RLD
        }

        type Query {
          hello: Hello
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func emptyUnion() throws {
        let sdl = """
        union EmptyUnion
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleUnion() throws {
        let sdl = """
        union Hello = World

        type Query {
          hello: Hello
        }

        type World {
          str: String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func multipleUnion() throws {
        let sdl = """
        union Hello = WorldOne | WorldTwo

        type Query {
          hello: Hello
        }

        type WorldOne {
          str: String
        }

        type WorldTwo {
          str: String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func canBuildRecursiveUnion() throws {
        #expect(
            throws: (any Error).self,
            "Union type Hello can only include Object types, it cannot include Hello"
        ) {
            try buildSchema(source: """
            union Hello = Hello

            type Query {
              hello: Hello
            }
            """)
        }
    }

    @Test func customScalar() throws {
        let sdl = """
        scalar CustomScalar

        type Query {
          customScalar: CustomScalar
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func emptyInputObject() throws {
        let sdl = """
        input EmptyInputObject
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleInputObject() throws {
        let sdl = """
        input Input {
          int: Int
        }

        type Query {
          field(in: Input): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleArgumentFieldWithDefault() throws {
        let sdl = """
        type Query {
          str(int: Int = 2): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func customScalarArgumentFieldWithDefault() throws {
        let sdl = """
        scalar CustomScalar

        type Query {
          str(int: CustomScalar = 2): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleTypeWithMutation() throws {
        let sdl = """
        schema {
          query: HelloScalars
          mutation: Mutation
        }

        type HelloScalars {
          str: String
          int: Int
          bool: Boolean
        }

        type Mutation {
          addHelloScalars(str: String, int: Int, bool: Boolean): HelloScalars
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func simpleTypeWithSubscription() throws {
        let sdl = """
        schema {
          query: HelloScalars
          subscription: Subscription
        }

        type HelloScalars {
          str: String
          int: Int
          bool: Boolean
        }

        type Subscription {
          subscribeHelloScalars(str: String, int: Int, bool: Boolean): HelloScalars
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func unreferencedTypeImplementingReferencedInterface() throws {
        let sdl = """
        type Concrete implements Interface {
          key: String
        }

        interface Interface {
          key: String
        }

        type Query {
          interface: Interface
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func unreferencedInterfaceImplementingReferencedInterface() throws {
        let sdl = """
        interface Child implements Parent {
          key: String
        }

        interface Parent {
          key: String
        }

        type Query {
          interfaceField: Parent
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func unreferencedTypeImplementingReferencedUnion() throws {
        let sdl = """
        type Concrete {
          key: String
        }

        type Query {
          union: Union
        }

        union Union = Concrete
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)
    }

    @Test func supportsDeprecated() throws {
        let sdl = """
        enum MyEnum {
          VALUE
          OLD_VALUE @deprecated
          OTHER_VALUE @deprecated(reason: "Terrible reasons")
        }

        input MyInput {
          oldInput: String @deprecated
          otherInput: String @deprecated(reason: "Use newInput")
          newInput: String
        }

        type Query {
          field1: String @deprecated
          field2: Int @deprecated(reason: "Because I said so")
          enum: MyEnum
          field3(oldArg: String @deprecated, arg: String): String
          field4(oldArg: String @deprecated(reason: "Why not?"), arg: String): String
          field5(arg: MyInput): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)

        let schema = try buildSchema(source: sdl)

        let myEnum = try #require(schema.getType(name: "MyEnum") as? GraphQLEnumType)

        let value = try #require(myEnum.nameLookup["VALUE"])
        #expect(value.deprecationReason == nil)

        let oldValue = try #require(myEnum.nameLookup["OLD_VALUE"])
        #expect(oldValue.deprecationReason == "No longer supported")

        let otherValue = try #require(myEnum.nameLookup["OTHER_VALUE"])
        #expect(otherValue.deprecationReason == "Terrible reasons")

        let rootFields = try #require(schema.getType(name: "Query") as? GraphQLObjectType)
            .getFields()
        #expect(rootFields["field1"]?.deprecationReason == "No longer supported")
        #expect(rootFields["field2"]?.deprecationReason == "Because I said so")

        let inputFields = try #require(
            schema.getType(name: "MyInput") as? GraphQLInputObjectType
        ).getFields()
        #expect(inputFields["newInput"]?.deprecationReason == nil)
        #expect(inputFields["oldInput"]?.deprecationReason == "No longer supported")
        #expect(inputFields["otherInput"]?.deprecationReason == "Use newInput")
        #expect(rootFields["field3"]?.args[0].deprecationReason == "No longer supported")
        #expect(rootFields["field4"]?.args[0].deprecationReason == "Why not?")
    }

    @Test func supportsSpecifiedBy() throws {
        let sdl = """
        scalar Foo @specifiedBy(url: "https://example.com/foo_spec")

        type Query {
          foo: Foo @deprecated
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)

        let schema = try buildSchema(source: sdl)

        let fooScalar = try #require(schema.getType(name: "Foo") as? GraphQLScalarType)
        #expect(fooScalar.specifiedByURL == "https://example.com/foo_spec")
    }

    @Test func correctlyExtendScalarType() throws {
        let schema = try buildSchema(source: """
        scalar SomeScalar
        extend scalar SomeScalar @foo
        extend scalar SomeScalar @bar

        directive @foo on SCALAR
        directive @bar on SCALAR
        """)
        let someScalar = try #require(schema.getType(name: "SomeScalar") as? GraphQLScalarType)
        #expect(
            printType(type: someScalar) == """
            scalar SomeScalar
            """
        )
        try #expect(print(ast: #require(someScalar.astNode)) == "scalar SomeScalar")
        #expect(
            someScalar.extensionASTNodes.map { print(ast: $0) } == [
                "extend scalar SomeScalar @foo",
                "extend scalar SomeScalar @bar",
            ]
        )
    }

    @Test func correctlyExtendObjectType() throws {
        let schema = try buildSchema(source: """
        type SomeObject implements Foo {
          first: String
        }

        extend type SomeObject implements Bar {
          second: Int
        }

        extend type SomeObject implements Baz {
          third: Float
        }

        interface Foo
        interface Bar
        interface Baz
        """)
        let someObject = try #require(schema.getType(name: "SomeObject") as? GraphQLObjectType)
        #expect(
            printType(type: someObject) == """
            type SomeObject implements Foo & Bar & Baz {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try #expect(
            print(ast: #require(someObject.astNode)) == """
            type SomeObject implements Foo {
              first: String
            }
            """
        )
        #expect(
            someObject.extensionASTNodes.map { print(ast: $0) } == [
                """
                extend type SomeObject implements Bar {
                  second: Int
                }
                """,
                """
                extend type SomeObject implements Baz {
                  third: Float
                }
                """,
            ]
        )
    }

    @Test func correctlyExtendInterfaceType() throws {
        let schema = try buildSchema(source: """
        interface SomeInterface {
          first: String
        }

        extend interface SomeInterface {
          second: Int
        }

        extend interface SomeInterface {
          third: Float
        }
        """)
        let someInterface = try #require(
            schema.getType(name: "SomeInterface") as? GraphQLInterfaceType
        )
        #expect(
            printType(type: someInterface) == """
            interface SomeInterface {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try #expect(
            print(ast: #require(someInterface.astNode)) == """
            interface SomeInterface {
              first: String
            }
            """
        )
        #expect(
            someInterface.extensionASTNodes.map { print(ast: $0) } == [
                """
                extend interface SomeInterface {
                  second: Int
                }
                """,
                """
                extend interface SomeInterface {
                  third: Float
                }
                """,
            ]
        )
    }

    @Test func correctlyExtendUnionType() throws {
        let schema = try buildSchema(source: """
        union SomeUnion = FirstType
        extend union SomeUnion = SecondType
        extend union SomeUnion = ThirdType

        type FirstType
        type SecondType
        type ThirdType
        """)
        let someUnion = try #require(schema.getType(name: "SomeUnion") as? GraphQLUnionType)
        #expect(
            printType(type: someUnion) == """
            union SomeUnion = FirstType | SecondType | ThirdType
            """
        )
        try #expect(
            print(
                ast: #require(someUnion.astNode)
            ) == "union SomeUnion = FirstType"
        )
        #expect(
            someUnion.extensionASTNodes.map { print(ast: $0) } == [
                "extend union SomeUnion = SecondType",
                "extend union SomeUnion = ThirdType",
            ]
        )
    }

    @Test func correctlyExtendEnumType() throws {
        let schema = try buildSchema(source: """
        enum SomeEnum {
          FIRST
        }

        extend enum SomeEnum {
          SECOND
        }

        extend enum SomeEnum {
          THIRD
        }
        """)
        let someEnum = try #require(schema.getType(name: "SomeEnum") as? GraphQLEnumType)
        #expect(
            printType(type: someEnum) == """
            enum SomeEnum {
              FIRST
              SECOND
              THIRD
            }
            """
        )
        try #expect(
            print(ast: #require(someEnum.astNode)) == """
            enum SomeEnum {
              FIRST
            }
            """
        )
        #expect(
            someEnum.extensionASTNodes.map { print(ast: $0) } == [
                """
                extend enum SomeEnum {
                  SECOND
                }
                """,
                """
                extend enum SomeEnum {
                  THIRD
                }
                """,
            ]
        )
    }

    @Test func correctlyExtendInputObjectType() throws {
        let schema = try buildSchema(source: """
        input SomeInput {
          first: String
        }

        extend input SomeInput {
          second: Int
        }

        extend input SomeInput {
          third: Float
        }
        """)
        let someInput = try #require(schema.getType(name: "SomeInput") as? GraphQLInputObjectType)
        #expect(
            printType(type: someInput) == """
            input SomeInput {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try #expect(
            print(ast: #require(someInput.astNode)) == """
            input SomeInput {
              first: String
            }
            """
        )
        #expect(
            someInput.extensionASTNodes.map { print(ast: $0) } == [
                """
                extend input SomeInput {
                  second: Int
                }
                """,
                """
                extend input SomeInput {
                  third: Float
                }
                """,
            ]
        )
    }

    @Test func correctlyAssignASTNodes() throws {
        let sdl = """
        schema {
          query: Query
        }

        type Query {
          testField(testArg: TestInput): TestUnion
        }

        input TestInput {
          testInputField: TestEnum
        }

        enum TestEnum {
          TEST_VALUE
        }

        union TestUnion = TestType

        interface TestInterface {
          interfaceField: String
        }

        type TestType implements TestInterface {
          interfaceField: String
        }

        scalar TestScalar

        directive @test(arg: TestScalar) on FIELD
        """
        let ast = try parse(source: sdl, noLocation: true)

        let schema = try buildASTSchema(documentAST: ast)
        let query = try #require(schema.getType(name: "Query") as? GraphQLObjectType)
        let testInput = try #require(schema.getType(name: "TestInput") as? GraphQLInputObjectType)
        let testEnum = try #require(schema.getType(name: "TestEnum") as? GraphQLEnumType)
        #expect(schema.getType(name: "TestUnion") as? GraphQLUnionType != nil)
        let testInterface = try #require(
            schema.getType(name: "TestInterface") as? GraphQLInterfaceType
        )
        let testType = try #require(schema.getType(name: "TestType") as? GraphQLObjectType)
        #expect(schema.getType(name: "TestScalar") as? GraphQLScalarType != nil)
        let testDirective = try #require(schema.getDirective(name: "test"))

        // No `Equatable` conformance
//        #expect(
//            [
//              schema.astNode,
//              query.astNode,
//              testInput.astNode,
//              testEnum.astNode,
//              testUnion.astNode,
//              testInterface.astNode,
//              testType.astNode,
//              testScalar.astNode,
//              testDirective.astNode,
//            ] ==
//            ast.definitions
//        )

        let testField = try #require(query.getFields()["testField"])
        try #expect(
            print(
                ast: #require(testField.astNode)
            ) == "testField(testArg: TestInput): TestUnion"
        )
        try #expect(
            print(
                ast: #require(testField.args[0].astNode)
            ) == "testArg: TestInput"
        )
        try #expect(
            print(
                ast: #require(testInput.getFields()["testInputField"]?.astNode)
            ) == "testInputField: TestEnum"
        )

        try #expect(
            print(
                ast: #require(testEnum.nameLookup["TEST_VALUE"]?.astNode)
            ) == "TEST_VALUE"
        )

        try #expect(
            print(
                ast: #require(testInterface.getFields()["interfaceField"]?.astNode)
            ) == "interfaceField: String"
        )
        try #expect(
            print(
                ast: #require(testType.getFields()["interfaceField"]?.astNode)
            ) == "interfaceField: String"
        )
        try #expect(
            print(
                ast: #require(testDirective.args[0].astNode)
            ) == "arg: TestScalar"
        )
    }

    @Test func rootOperationTypesWithCustomNames() throws {
        let schema = try buildSchema(source: """
        schema {
          query: SomeQuery
          mutation: SomeMutation
          subscription: SomeSubscription
        }
        type SomeQuery
        type SomeMutation
        type SomeSubscription
        """)
        #expect(schema.queryType?.name == "SomeQuery")
        #expect(schema.mutationType?.name == "SomeMutation")
        #expect(schema.subscriptionType?.name == "SomeSubscription")
    }

    @Test func defaultRootOperationTypeNames() throws {
        let schema = try buildSchema(source: """
        type Query
        type Mutation
        type Subscription
        """)
        #expect(schema.queryType?.name == "Query")
        #expect(schema.mutationType?.name == "Mutation")
        #expect(schema.subscriptionType?.name == "Subscription")
    }

    @Test func canBuildInvalidSchema() throws {
        let schema = try buildSchema(source: "type Mutation")
        let errors = try validateSchema(schema: schema)
        #expect(errors.count > 0)
    }

    @Test func doNotOverrideStandardTypes() throws {
        let schema = try buildSchema(source: """
        scalar ID

        scalar __Schema
        """)
        #expect(
            schema.getType(name: "ID") as? GraphQLScalarType ===
                GraphQLID
        )
        #expect(
            schema.getType(name: "__Schema") as? GraphQLObjectType ===
                __Schema
        )
    }

    @Test func allowsToReferenceIntrospectionTypes() throws {
        let schema = try buildSchema(source: """
        type Query {
          introspectionField: __EnumValue
        }
        """)
        let queryType = try #require(schema.getType(name: "Query") as? GraphQLObjectType)
        try #expect(
            queryType.getFields().contains { key, field in
                key == "introspectionField" &&
                    (field.type as? GraphQLObjectType) === __EnumValue
            }
        )
        #expect(
            schema.getType(name: "__EnumValue") as? GraphQLObjectType ===
                __EnumValue
        )
    }

    @Test func rejectsInvalidSDL() throws {
        let sdl = """
        type Query {
          foo: String @unknown
        }
        """
        #expect(
            throws: (any Error).self,
            "Unknown directive: \"@unknown\"."
        ) {
            try buildSchema(source: sdl)
        }
    }

    @Test func allowsToDisableSDLValidation() throws {
        let sdl = """
        type Query {
          foo: String @unknown
        }
        """
        _ = try buildSchema(source: sdl, assumeValid: true)
        _ = try buildSchema(source: sdl, assumeValidSDL: true)
    }

    @Test func throwsOnUnknownTypes() throws {
        let sdl = """
        type Query {
          unknown: UnknownType
        }
        """
        #expect(
            throws: (any Error).self,
            "Unknown type: \"@UnknownType\"."
        ) {
            try buildSchema(source: sdl)
        }
    }

    @Test func correctlyProcessesViralSchema() throws {
        let schema = try buildSchema(source: """
        schema {
          query: Query
        }

        type Query {
          viruses: [Virus!]
        }

        type Virus {
          name: String!
          knownMutations: [Mutation!]!
        }

        type Mutation {
          name: String!
          geneSequence: String!
        }
        """)
        #expect(schema.queryType?.name == "Query")
        #expect(schema.getType(name: "Virus")?.name == "Virus")
        #expect(schema.getType(name: "Mutation")?.name == "Mutation")
        // Though the viral schema has a 'Mutation' type, it is not used for the
        // 'mutation' operation.
        #expect(schema.mutationType == nil)
    }

    @Test func supportsNullLiterals() throws {
        let sdl = """
        input MyInput {
          nullLiteral: String!
        }

        type Query {
          field(in: MyInput = null): String
        }
        """
        try #expect(cycleSDL(sdl: sdl) == sdl)

        let schema = try buildSchema(source: sdl)

        let rootFields = try #require(schema.getType(name: "Query") as? GraphQLObjectType)
            .getFields()
        #expect(rootFields["field"]?.args[0].defaultValue == .null)
    }
}
