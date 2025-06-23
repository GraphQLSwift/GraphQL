@testable import GraphQL
import XCTest

class BuildASTSchemaTests: XCTestCase {
    /**
     * This function does a full cycle of going from a string with the contents of
     * the SDL, parsed in a schema AST, materializing that schema AST into an
     * in-memory GraphQLSchema, and then finally printing that object into the SDL
     */
    func cycleSDL(sdl: String) throws -> String {
        return try printSchema(schema: buildSchema(source: sdl))
    }

    func testCanUseBuiltSchemaForLimitedExecution() async throws {
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

        XCTAssertEqual(
            result,
            GraphQLResult(data: [
                "str": "123",
            ])
        )
    }

    // Closures are invalid Map keys in Swift.
//    func testCanBuildASchemaDirectlyFromTheSource() throws {
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
//        XCTAssertEqual(
//            result,
//            GraphQLResult(data: [
//                "add": 89
//            ])
//        )
//    }

    func testIgnoresNonTypeSystemDefinitions() throws {
        let sdl = """
        type Query {
          str: String
        }

        fragment SomeFragment on Query {
          str
        }
        """

        XCTAssertNoThrow(try buildSchema(source: sdl))
    }

    func testMatchOrderOfDefaultTypesAndDirectives() throws {
        let schema = try GraphQLSchema()
        let sdlSchema = try buildASTSchema(documentAST: .init(definitions: []))

        XCTAssertEqual(sdlSchema.directives.map { $0.name }, schema.directives.map { $0.name })
        XCTAssertEqual(
            sdlSchema.typeMap.mapValues { $0.name },
            schema.typeMap.mapValues { $0.name }
        )
    }

    func testEmptyType() throws {
        let sdl = """
        type EmptyType
        """

        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleType() throws {
        let sdl = """
        type Query {
          str: String
          int: Int
          float: Float
          id: ID
          bool: Boolean
        }
        """

        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)

        let schema = try buildSchema(source: sdl)
        // Built-ins are used
        XCTAssertIdentical(
            schema.getType(name: "Int") as? GraphQLScalarType,
            GraphQLInt
        )
        XCTAssertEqual(
            schema.getType(name: "Float") as? GraphQLScalarType,
            GraphQLFloat
        )
        XCTAssertEqual(
            schema.getType(name: "String") as? GraphQLScalarType,
            GraphQLString
        )
        XCTAssertEqual(
            schema.getType(name: "Boolean") as? GraphQLScalarType,
            GraphQLBoolean
        )
        XCTAssertEqual(
            schema.getType(name: "ID") as? GraphQLScalarType,
            GraphQLID
        )
    }

    func testIncludeStandardTypeOnlyIfItIsUsed() throws {
        let schema = try buildSchema(source: "type Query")

        // String and Boolean are always included through introspection types
        XCTAssertNil(schema.getType(name: "Int"))
        XCTAssertNil(schema.getType(name: "Float"))
        XCTAssertNil(schema.getType(name: "ID"))
    }

    func testWithDirectives() throws {
        let sdl = """
        directive @foo(arg: Int) on FIELD

        directive @repeatableFoo(arg: Int) repeatable on FIELD
        """

        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSupportsDescriptions() throws {
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

        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testMaintainsIncludeSkipAndSpecifiedBy() throws {
        let schema = try buildSchema(source: "type Query")

        XCTAssertEqual(schema.directives.count, 5)
        XCTAssertIdentical(
            schema.getDirective(name: GraphQLSkipDirective.name),
            GraphQLSkipDirective
        )
        XCTAssertIdentical(
            schema.getDirective(name: GraphQLIncludeDirective.name),
            GraphQLIncludeDirective
        )
        XCTAssertIdentical(
            schema.getDirective(name: GraphQLDeprecatedDirective.name),
            GraphQLDeprecatedDirective
        )
        XCTAssertIdentical(
            schema.getDirective(name: GraphQLSpecifiedByDirective.name),
            GraphQLSpecifiedByDirective
        )
        XCTAssertIdentical(
            schema.getDirective(name: GraphQLOneOfDirective.name),
            GraphQLOneOfDirective
        )
    }

    func testOverridingDirectivesExcludesSpecified() throws {
        let schema = try buildSchema(source: """
        directive @skip on FIELD
        directive @include on FIELD
        directive @deprecated on FIELD_DEFINITION
        directive @specifiedBy on FIELD_DEFINITION
        directive @oneOf on OBJECT
        """)

        XCTAssertEqual(schema.directives.count, 5)
        XCTAssertNotIdentical(
            schema.getDirective(name: GraphQLSkipDirective.name),
            GraphQLSkipDirective
        )
        XCTAssertNotIdentical(
            schema.getDirective(name: GraphQLIncludeDirective.name),
            GraphQLIncludeDirective
        )
        XCTAssertNotIdentical(
            schema.getDirective(name: GraphQLDeprecatedDirective.name),
            GraphQLDeprecatedDirective
        )
        XCTAssertNotIdentical(
            schema.getDirective(name: GraphQLSpecifiedByDirective.name),
            GraphQLSpecifiedByDirective
        )
        XCTAssertNotIdentical(
            schema.getDirective(name: GraphQLOneOfDirective.name),
            GraphQLOneOfDirective
        )
    }

    func testAddingDirectivesMaintainsIncludeSkipDeprecatedSpecifiedByAndOneOf() throws {
        let schema = try buildSchema(source: """
        directive @foo(arg: Int) on FIELD
        """)

        XCTAssertEqual(schema.directives.count, 6)
        XCTAssertNotNil(schema.getDirective(name: GraphQLSkipDirective.name))
        XCTAssertNotNil(schema.getDirective(name: GraphQLIncludeDirective.name))
        XCTAssertNotNil(schema.getDirective(name: GraphQLDeprecatedDirective.name))
        XCTAssertNotNil(schema.getDirective(name: GraphQLSpecifiedByDirective.name))
        XCTAssertNotNil(schema.getDirective(name: GraphQLOneOfDirective.name))
    }

    func testTypeModifiers() throws {
        let sdl = """
        type Query {
          nonNullStr: String!
          listOfStrings: [String]
          listOfNonNullStrings: [String!]
          nonNullListOfStrings: [String]!
          nonNullListOfNonNullStrings: [String!]!
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testRecursiveType() throws {
        let sdl = """
        type Query {
          str: String
          recurse: Query
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testTwoTypesCircular() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSingleArgumentField() throws {
        let sdl = """
        type Query {
          str(int: Int): String
          floatToStr(float: Float): String
          idToStr(id: ID): String
          booleanToStr(bool: Boolean): String
          strToStr(bool: String): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleTypeWithMultipleArguments() throws {
        let sdl = """
        type Query {
          str(int: Int, bool: Boolean): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testEmptyInterface() throws {
        let sdl = """
        interface EmptyInterface
        """
        let definition = try XCTUnwrap(
            parse(source: sdl)
                .definitions[0] as? InterfaceTypeDefinition
        )
        XCTAssertEqual(definition.interfaces, [])
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleTypeWithInterface() throws {
        let sdl = """
        type Query implements WorldInterface {
          str: String
        }

        interface WorldInterface {
          str: String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleInterfaceHierarchy() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testEmptyEnum() throws {
        let sdl = """
        enum EmptyEnum
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleOutputEnum() throws {
        let sdl = """
        enum Hello {
          WORLD
        }

        type Query {
          hello: Hello
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleInputEnum() throws {
        let sdl = """
        enum Hello {
          WORLD
        }

        type Query {
          str(hello: Hello): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testMultipleValueEnum() throws {
        let sdl = """
        enum Hello {
          WO
          RLD
        }

        type Query {
          hello: Hello
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testEmptyUnion() throws {
        let sdl = """
        union EmptyUnion
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleUnion() throws {
        let sdl = """
        union Hello = World

        type Query {
          hello: Hello
        }

        type World {
          str: String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testMultipleUnion() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testCanBuildRecursiveUnion() throws {
        XCTAssertThrowsError(
            try buildSchema(source: """
            union Hello = Hello

            type Query {
              hello: Hello
            }
            """),
            "Union type Hello can only include Object types, it cannot include Hello"
        )
    }

    func testCustomScalar() throws {
        let sdl = """
        scalar CustomScalar

        type Query {
          customScalar: CustomScalar
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testEmptyInputObject() throws {
        let sdl = """
        input EmptyInputObject
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleInputObject() throws {
        let sdl = """
        input Input {
          int: Int
        }

        type Query {
          field(in: Input): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleArgumentFieldWithDefault() throws {
        let sdl = """
        type Query {
          str(int: Int = 2): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testCustomScalarArgumentFieldWithDefault() throws {
        let sdl = """
        scalar CustomScalar

        type Query {
          str(int: CustomScalar = 2): String
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleTypeWithMutation() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSimpleTypeWithSubscription() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testUnreferencedTypeImplementingReferencedInterface() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testUnreferencedInterfaceImplementingReferencedInterface() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testUnreferencedTypeImplementingReferencedUnion() throws {
        let sdl = """
        type Concrete {
          key: String
        }

        type Query {
          union: Union
        }

        union Union = Concrete
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)
    }

    func testSupportsDeprecated() throws {
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
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)

        let schema = try buildSchema(source: sdl)

        let myEnum = try XCTUnwrap(schema.getType(name: "MyEnum") as? GraphQLEnumType)

        let value = try XCTUnwrap(myEnum.nameLookup["VALUE"])
        XCTAssertNil(value.deprecationReason)

        let oldValue = try XCTUnwrap(myEnum.nameLookup["OLD_VALUE"])
        XCTAssertEqual(oldValue.deprecationReason, "No longer supported")

        let otherValue = try XCTUnwrap(myEnum.nameLookup["OTHER_VALUE"])
        XCTAssertEqual(otherValue.deprecationReason, "Terrible reasons")

        let rootFields = try XCTUnwrap(schema.getType(name: "Query") as? GraphQLObjectType)
            .getFields()
        XCTAssertEqual(rootFields["field1"]?.deprecationReason, "No longer supported")
        XCTAssertEqual(rootFields["field2"]?.deprecationReason, "Because I said so")

        let inputFields = try XCTUnwrap(
            schema.getType(name: "MyInput") as? GraphQLInputObjectType
        ).getFields()
        XCTAssertNil(inputFields["newInput"]?.deprecationReason)
        XCTAssertEqual(inputFields["oldInput"]?.deprecationReason, "No longer supported")
        XCTAssertEqual(inputFields["otherInput"]?.deprecationReason, "Use newInput")
        XCTAssertEqual(rootFields["field3"]?.args[0].deprecationReason, "No longer supported")
        XCTAssertEqual(rootFields["field4"]?.args[0].deprecationReason, "Why not?")
    }

    func testSupportsSpecifiedBy() throws {
        let sdl = """
        scalar Foo @specifiedBy(url: "https://example.com/foo_spec")

        type Query {
          foo: Foo @deprecated
        }
        """
        try XCTAssertEqual(cycleSDL(sdl: sdl), sdl)

        let schema = try buildSchema(source: sdl)

        let fooScalar = try XCTUnwrap(schema.getType(name: "Foo") as? GraphQLScalarType)
        XCTAssertEqual(fooScalar.specifiedByURL, "https://example.com/foo_spec")
    }

    func testCorrectlyExtendScalarType() throws {
        let schema = try buildSchema(source: """
        scalar SomeScalar
        extend scalar SomeScalar @foo
        extend scalar SomeScalar @bar

        directive @foo on SCALAR
        directive @bar on SCALAR
        """)
        let someScalar = try XCTUnwrap(schema.getType(name: "SomeScalar") as? GraphQLScalarType)
        XCTAssertEqual(
            printType(type: someScalar),
            """
            scalar SomeScalar
            """
        )
        try XCTAssertEqual(print(ast: XCTUnwrap(someScalar.astNode)), "scalar SomeScalar")
        XCTAssertEqual(
            someScalar.extensionASTNodes.map { print(ast: $0) },
            [
                "extend scalar SomeScalar @foo",
                "extend scalar SomeScalar @bar",
            ]
        )
    }

    func testCorrectlyExtendObjectType() throws {
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
        let someObject = try XCTUnwrap(schema.getType(name: "SomeObject") as? GraphQLObjectType)
        XCTAssertEqual(
            printType(type: someObject),
            """
            type SomeObject implements Foo & Bar & Baz {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(someObject.astNode)),
            """
            type SomeObject implements Foo {
              first: String
            }
            """
        )
        XCTAssertEqual(
            someObject.extensionASTNodes.map { print(ast: $0) },
            [
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

    func testCorrectlyExtendInterfaceType() throws {
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
        let someInterface = try XCTUnwrap(
            schema.getType(name: "SomeInterface") as? GraphQLInterfaceType
        )
        XCTAssertEqual(
            printType(type: someInterface),
            """
            interface SomeInterface {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(someInterface.astNode)),
            """
            interface SomeInterface {
              first: String
            }
            """
        )
        XCTAssertEqual(
            someInterface.extensionASTNodes.map { print(ast: $0) },
            [
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

    func testCorrectlyExtendUnionType() throws {
        let schema = try buildSchema(source: """
        union SomeUnion = FirstType
        extend union SomeUnion = SecondType
        extend union SomeUnion = ThirdType

        type FirstType
        type SecondType
        type ThirdType
        """)
        let someUnion = try XCTUnwrap(schema.getType(name: "SomeUnion") as? GraphQLUnionType)
        XCTAssertEqual(
            printType(type: someUnion),
            """
            union SomeUnion = FirstType | SecondType | ThirdType
            """
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(someUnion.astNode)),
            "union SomeUnion = FirstType"
        )
        XCTAssertEqual(
            someUnion.extensionASTNodes.map { print(ast: $0) },
            [
                "extend union SomeUnion = SecondType",
                "extend union SomeUnion = ThirdType",
            ]
        )
    }

    func testCorrectlyExtendEnumType() throws {
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
        let someEnum = try XCTUnwrap(schema.getType(name: "SomeEnum") as? GraphQLEnumType)
        XCTAssertEqual(
            printType(type: someEnum),
            """
            enum SomeEnum {
              FIRST
              SECOND
              THIRD
            }
            """
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(someEnum.astNode)),
            """
            enum SomeEnum {
              FIRST
            }
            """
        )
        XCTAssertEqual(
            someEnum.extensionASTNodes.map { print(ast: $0) },
            [
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

    func testCorrectlyExtendInputObjectType() throws {
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
        let someInput = try XCTUnwrap(schema.getType(name: "SomeInput") as? GraphQLInputObjectType)
        XCTAssertEqual(
            printType(type: someInput),
            """
            input SomeInput {
              first: String
              second: Int
              third: Float
            }
            """
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(someInput.astNode)),
            """
            input SomeInput {
              first: String
            }
            """
        )
        XCTAssertEqual(
            someInput.extensionASTNodes.map { print(ast: $0) },
            [
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

    func testCorrectlyAssignASTNodes() throws {
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
        let query = try XCTUnwrap(schema.getType(name: "Query") as? GraphQLObjectType)
        let testInput = try XCTUnwrap(schema.getType(name: "TestInput") as? GraphQLInputObjectType)
        let testEnum = try XCTUnwrap(schema.getType(name: "TestEnum") as? GraphQLEnumType)
        let _ = try XCTUnwrap(schema.getType(name: "TestUnion") as? GraphQLUnionType)
        let testInterface = try XCTUnwrap(
            schema.getType(name: "TestInterface") as? GraphQLInterfaceType
        )
        let testType = try XCTUnwrap(schema.getType(name: "TestType") as? GraphQLObjectType)
        let _ = try XCTUnwrap(schema.getType(name: "TestScalar") as? GraphQLScalarType)
        let testDirective = try XCTUnwrap(schema.getDirective(name: "test"))

        // No `Equatable` conformance
//        XCTAssertEqual(
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
//            ],
//            ast.definitions
//        )

        let testField = try XCTUnwrap(query.getFields()["testField"])
        try XCTAssertEqual(
            print(ast: XCTUnwrap(testField.astNode)),
            "testField(testArg: TestInput): TestUnion"
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(testField.args[0].astNode)),
            "testArg: TestInput"
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(testInput.getFields()["testInputField"]?.astNode)),
            "testInputField: TestEnum"
        )

        try XCTAssertEqual(
            print(ast: XCTUnwrap(testEnum.nameLookup["TEST_VALUE"]?.astNode)),
            "TEST_VALUE"
        )

        try XCTAssertEqual(
            print(ast: XCTUnwrap(testInterface.getFields()["interfaceField"]?.astNode)),
            "interfaceField: String"
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(testType.getFields()["interfaceField"]?.astNode)),
            "interfaceField: String"
        )
        try XCTAssertEqual(
            print(ast: XCTUnwrap(testDirective.args[0].astNode)),
            "arg: TestScalar"
        )
    }

    func testRootOperationTypesWithCustomNames() throws {
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
        XCTAssertEqual(schema.queryType?.name, "SomeQuery")
        XCTAssertEqual(schema.mutationType?.name, "SomeMutation")
        XCTAssertEqual(schema.subscriptionType?.name, "SomeSubscription")
    }

    func testDefaultRootOperationTypeNames() throws {
        let schema = try buildSchema(source: """
        type Query
        type Mutation
        type Subscription
        """)
        XCTAssertEqual(schema.queryType?.name, "Query")
        XCTAssertEqual(schema.mutationType?.name, "Mutation")
        XCTAssertEqual(schema.subscriptionType?.name, "Subscription")
    }

    func testCanBuildInvalidSchema() throws {
        let schema = try buildSchema(source: "type Mutation")
        let errors = try validateSchema(schema: schema)
        XCTAssertGreaterThan(errors.count, 0)
    }

    func testDoNotOverrideStandardTypes() throws {
        let schema = try buildSchema(source: """
        scalar ID

        scalar __Schema
        """)
        XCTAssertIdentical(
            schema.getType(name: "ID") as? GraphQLScalarType,
            GraphQLID
        )
        XCTAssertIdentical(
            schema.getType(name: "__Schema") as? GraphQLObjectType,
            __Schema
        )
    }

    func testAllowsToReferenceIntrospectionTypes() throws {
        let schema = try buildSchema(source: """
        type Query {
          introspectionField: __EnumValue
        }
        """)
        let queryType = try XCTUnwrap(schema.getType(name: "Query") as? GraphQLObjectType)
        try XCTAssert(
            queryType.getFields().contains { key, field in
                key == "introspectionField" &&
                    (field.type as? GraphQLObjectType) === __EnumValue
            }
        )
        XCTAssertIdentical(
            schema.getType(name: "__EnumValue") as? GraphQLObjectType,
            __EnumValue
        )
    }

    func testRejectsInvalidSDL() throws {
        let sdl = """
        type Query {
          foo: String @unknown
        }
        """
        XCTAssertThrowsError(
            try buildSchema(source: sdl),
            "Unknown directive \"@unknown\"."
        )
    }

    func testAllowsToDisableSDLValidation() throws {
        let sdl = """
        type Query {
          foo: String @unknown
        }
        """
        _ = try buildSchema(source: sdl, assumeValid: true)
        _ = try buildSchema(source: sdl, assumeValidSDL: true)
    }

    func testThrowsOnUnknownTypes() throws {
        let sdl = """
        type Query {
          unknown: UnknownType
        }
        """
        XCTAssertThrowsError(
            try buildSchema(source: sdl),
            "Unknown type: \"@UnknownType\"."
        )
    }

    func testCorrectlyProcessesViralSchema() throws {
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
        XCTAssertEqual(schema.queryType?.name, "Query")
        XCTAssertEqual(schema.getType(name: "Virus")?.name, "Virus")
        XCTAssertEqual(schema.getType(name: "Mutation")?.name, "Mutation")
        // Though the viral schema has a 'Mutation' type, it is not used for the
        // 'mutation' operation.
        XCTAssertNil(schema.mutationType)
    }
}
