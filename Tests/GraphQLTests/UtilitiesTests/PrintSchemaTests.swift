@testable import GraphQL
import OrderedCollections
import XCTest

func expectPrintedSchema(schema: GraphQLSchema) throws -> String {
    let schemaText = printSchema(schema: schema)
    // keep printSchema and buildSchema in sync
    XCTAssertEqual(try printSchema(schema: buildSchema(source: schemaText)), schemaText)
    return schemaText
}

func buildSingleFieldSchema(
    fieldConfig: GraphQLField
) throws -> GraphQLSchema {
    let Query = try GraphQLObjectType(
        name: "Query",
        fields: ["singleField": fieldConfig]
    )
    return try GraphQLSchema(query: Query)
}

class TypeSystemPrinterTests: XCTestCase {
    func testPrintsStringField() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(type: GraphQLString))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: String
        }
        """)
    }

    func testPrintsStringListField() throws {
        let schema =
            try buildSingleFieldSchema(fieldConfig: GraphQLField(type: GraphQLList(GraphQLString)))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: [String]
        }
        """)
    }

    func testPrintsStringNonNullField() throws {
        let schema =
            try buildSingleFieldSchema(
                fieldConfig: GraphQLField(type: GraphQLNonNull(GraphQLString))
            )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: String!
        }
        """)
    }

    func testPrintsStringNonNullListField() throws {
        let schema =
            try buildSingleFieldSchema(
                fieldConfig: GraphQLField(type: GraphQLNonNull(GraphQLList(GraphQLString)))
            )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: [String]!
        }
        """)
    }

    func testPrintsStringListNonNullsField() throws {
        let schema =
            try buildSingleFieldSchema(
                fieldConfig: GraphQLField(type: GraphQLList(GraphQLNonNull(GraphQLString)))
            )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: [String!]
        }
        """)
    }

    func testPrintsStringNonNullListNonNullsField() throws {
        let schema =
            try buildSingleFieldSchema(
                fieldConfig: GraphQLField(
                    type: GraphQLNonNull(GraphQLList(GraphQLNonNull(GraphQLString)))
                )
            )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField: [String!]!
        }
        """)
    }

    func testPrintsObjectField() throws {
        let FooType = try GraphQLObjectType(
            name: "Foo",
            fields: ["str": GraphQLField(type: GraphQLString)]
        )
        let schema = try GraphQLSchema(types: [FooType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Foo {
          str: String
        }
        """)
    }

    func testPrintsStringFieldWithIntArg() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: ["argOne": GraphQLArgument(type: GraphQLInt)]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int): String
        }
        """)
    }

    func testPrintsStringFieldWithIntArgWithDefault() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: ["argOne": GraphQLArgument(type: GraphQLInt, defaultValue: 2)]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int = 2): String
        }
        """)
    }

    func testPrintsStringFieldWithStringArgWithDefault() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: ["argOne": GraphQLArgument(type: GraphQLString, defaultValue: "test default")]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: String = "test default"): String
        }
        """)
    }

    func testPrintsStringFieldWithIntArgWithDefaultNull() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: ["argOne": GraphQLArgument(type: GraphQLInt, defaultValue: .null)]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int = null): String
        }
        """)
    }

    func testPrintsStringFieldWithNonNullIntArg() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: ["argOne": GraphQLArgument(type: GraphQLNonNull(GraphQLInt))]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int!): String
        }
        """)
    }

    func testPrintsStringFieldWithMultipleArgs() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: [
                "argOne": GraphQLArgument(type: GraphQLInt),
                "argTwo": GraphQLArgument(type: GraphQLString),
            ]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int, argTwo: String): String
        }
        """)
    }

    func testPrintsStringFieldWithMultipleArgsFirstIsDefault() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: [
                "argOne": GraphQLArgument(type: GraphQLInt, defaultValue: 1),
                "argTwo": GraphQLArgument(type: GraphQLString),
                "argThree": GraphQLArgument(type: GraphQLBoolean),
            ]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int = 1, argTwo: String, argThree: Boolean): String
        }
        """)
    }

    func testPrintsStringFieldWithMultipleArgsSecondIsDefault() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: [
                "argOne": GraphQLArgument(type: GraphQLInt),
                "argTwo": GraphQLArgument(type: GraphQLString, defaultValue: "foo"),
                "argThree": GraphQLArgument(type: GraphQLBoolean),
            ]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int, argTwo: String = "foo", argThree: Boolean): String
        }
        """)
    }

    func testPrintsStringFieldWithMultipleArgsLastIsDefault() throws {
        let schema = try buildSingleFieldSchema(fieldConfig: GraphQLField(
            type: GraphQLString,
            args: [
                "argOne": GraphQLArgument(type: GraphQLInt),
                "argTwo": GraphQLArgument(type: GraphQLString),
                "argThree": GraphQLArgument(type: GraphQLBoolean, defaultValue: .bool(false)),
            ]
        ))
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          singleField(argOne: Int, argTwo: String, argThree: Boolean = false): String
        }
        """)
    }

    func testPrintsSchemaWithDescription() throws {
        let schema = try GraphQLSchema(
            description: "Schema description.",
            query: GraphQLObjectType(name: "Query", fields: [:])
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), #"""
        """Schema description."""
        schema {
          query: Query
        }

        type Query
        """#)
    }

    func testOmitsSchemaOfCommonNames() throws {
        let schema = try GraphQLSchema(
            query: GraphQLObjectType(name: "Query", fields: [:]),
            mutation: GraphQLObjectType(name: "Mutation", fields: [:]),
            subscription: GraphQLObjectType(name: "Subscription", fields: [:])
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query

        type Mutation

        type Subscription
        """)
    }

    func testPrintsCustomQueryRootTypes() throws {
        let schema = try GraphQLSchema(
            query: GraphQLObjectType(name: "CustomType", fields: [:])
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        schema {
          query: CustomType
        }

        type CustomType
        """)
    }

    func testPrintsCustomMutationRootTypes() throws {
        let schema = try GraphQLSchema(
            mutation: GraphQLObjectType(name: "CustomType", fields: [:])
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        schema {
          mutation: CustomType
        }

        type CustomType
        """)
    }

    func testPrintsCustomSubscriptionRootTypes() throws {
        let schema = try GraphQLSchema(
            subscription: GraphQLObjectType(name: "CustomType", fields: [:])
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        schema {
          subscription: CustomType
        }

        type CustomType
        """)
    }

    func testPrintInterface() throws {
        let FooType = try GraphQLInterfaceType(
            name: "Foo",
            fields: ["str": GraphQLField(type: GraphQLString)]
        )

        let BarType = try GraphQLObjectType(
            name: "Bar",
            fields: ["str": GraphQLField(type: GraphQLString)],
            interfaces: [FooType]
        )

        let schema = try GraphQLSchema(types: [BarType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Bar implements Foo {
          str: String
        }

        interface Foo {
          str: String
        }
        """)
    }

    func testPrintMultipleInterface() throws {
        let FooType = try GraphQLInterfaceType(
            name: "Foo",
            fields: ["str": GraphQLField(type: GraphQLString)]
        )

        let BazType = try GraphQLInterfaceType(
            name: "Baz",
            fields: ["int": GraphQLField(type: GraphQLInt)]
        )

        let BarType = try GraphQLObjectType(
            name: "Bar",
            fields: [
                "str": GraphQLField(type: GraphQLString),
                "int": GraphQLField(type: GraphQLInt),
            ],
            interfaces: [FooType, BazType]
        )

        let schema = try GraphQLSchema(types: [BarType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Bar implements Foo & Baz {
          str: String
          int: Int
        }

        interface Foo {
          str: String
        }

        interface Baz {
          int: Int
        }
        """)
    }

    func testPrintHierarchicalInterface() throws {
        let FooType = try GraphQLInterfaceType(
            name: "Foo",
            fields: ["str": GraphQLField(type: GraphQLString)]
        )

        let BazType = try GraphQLInterfaceType(
            name: "Baz",
            interfaces: [FooType],
            fields: [
                "int": GraphQLField(type: GraphQLInt),
                "str": GraphQLField(type: GraphQLString),
            ]
        )

        let BarType = try GraphQLObjectType(
            name: "Bar",
            fields: [
                "str": GraphQLField(type: GraphQLString),
                "int": GraphQLField(type: GraphQLInt),
            ],
            interfaces: [FooType, BazType]
        )

        let Query = try GraphQLObjectType(
            name: "Query",
            fields: [
                "bar": GraphQLField(type: BarType),
            ]
        )

        let schema = try GraphQLSchema(query: Query, types: [BarType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Bar implements Foo & Baz {
          str: String
          int: Int
        }

        interface Foo {
          str: String
        }

        interface Baz implements Foo {
          int: Int
          str: String
        }

        type Query {
          bar: Bar
        }
        """)
    }

    func testPrintUnions() throws {
        let FooType = try GraphQLObjectType(
            name: "Foo",
            fields: ["bool": GraphQLField(type: GraphQLBoolean)]
        )

        let BarType = try GraphQLObjectType(
            name: "Bar",
            fields: ["str": GraphQLField(type: GraphQLString)]
        )

        let SingleUnion = try GraphQLUnionType(
            name: "SingleUnion",
            types: [FooType]
        )

        let MultipleUnion = try GraphQLUnionType(
            name: "MultipleUnion",
            types: [FooType, BarType]
        )

        let schema = try GraphQLSchema(types: [SingleUnion, MultipleUnion])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        union SingleUnion = Foo

        type Foo {
          bool: Boolean
        }

        union MultipleUnion = Foo | Bar

        type Bar {
          str: String
        }
        """)
    }

    func testPrintInputType() throws {
        let InputType = try GraphQLInputObjectType(
            name: "InputType",
            fields: ["int": InputObjectField(type: GraphQLInt)]
        )

        let schema = try GraphQLSchema(types: [InputType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        input InputType {
          int: Int
        }
        """)
    }

    func testPrintInputTypewithOneOfDirective() throws {
        let InputType = try GraphQLInputObjectType(
            name: "InputType",
            fields: ["int": InputObjectField(type: GraphQLInt)],
            isOneOf: true
        )

        let schema = try GraphQLSchema(types: [InputType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        input InputType @oneOf {
          int: Int
        }
        """)
    }

    func testCustomScalar() throws {
        let OddType = try GraphQLScalarType(name: "Odd")

        let schema = try GraphQLSchema(types: [OddType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        scalar Odd
        """)
    }

    func testCustomScalarWithSpecifiedByURL() throws {
        let FooType = try GraphQLScalarType(
            name: "Foo",
            specifiedByURL: "https://example.com/foo_spec"
        )

        let schema = try GraphQLSchema(types: [FooType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        scalar Foo @specifiedBy(url: "https://example.com/foo_spec")
        """)
    }

    func testEnum() throws {
        let RGBType = try GraphQLEnumType(
            name: "RGB",
            values: [
                "RED": GraphQLEnumValue(value: "RED"),
                "GREEN": GraphQLEnumValue(value: "GREEN"),
                "BLUE": GraphQLEnumValue(value: "BLUE"),
            ]
        )

        let schema = try GraphQLSchema(types: [RGBType])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        enum RGB {
          RED
          GREEN
          BLUE
        }
        """)
    }

    func testPrintsEmptyTypes() throws {
        let schema = try GraphQLSchema(
            types: [
                GraphQLEnumType(name: "SomeEnum", values: [:]),
                GraphQLInputObjectType(name: "SomeInputObject", fields: [:]),
                GraphQLInterfaceType(name: "SomeInterface", fields: [:]),
                GraphQLObjectType(name: "SomeObject", fields: [:]),
                GraphQLUnionType(name: "SomeUnion", types: []),
            ]
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        enum SomeEnum

        input SomeInputObject

        interface SomeInterface

        type SomeObject

        union SomeUnion
        """)
    }

    func testPrintsCustomDirectives() throws {
        let SimpleDirective = try GraphQLDirective(
            name: "simpleDirective",
            locations: [DirectiveLocation.field]
        )
        let ComplexDirective = try GraphQLDirective(
            name: "complexDirective",
            description: "Complex Directive",
            locations: [DirectiveLocation.field, DirectiveLocation.query],
            args: [
                "stringArg": GraphQLArgument(type: GraphQLString),
                "intArg": GraphQLArgument(type: GraphQLInt, defaultValue: -1),
            ],
            isRepeatable: true
        )

        let schema = try GraphQLSchema(directives: [SimpleDirective, ComplexDirective])
        try XCTAssertEqual(expectPrintedSchema(schema: schema), #"""
        directive @simpleDirective on FIELD

        """Complex Directive"""
        directive @complexDirective(stringArg: String, intArg: Int = -1) repeatable on FIELD | QUERY
        """#)
    }

    func testPrintsAnEmptyDescriptions() throws {
        let args: OrderedDictionary<String, GraphQLArgument> = [
            "someArg": GraphQLArgument(type: GraphQLString, description: ""),
            "anotherArg": GraphQLArgument(type: GraphQLString, description: ""),
        ]

        let fields: OrderedDictionary<String, GraphQLField> = [
            "someField": GraphQLField(type: GraphQLString, description: "", args: args),
            "anotherField": GraphQLField(type: GraphQLString, description: "", args: args),
        ]

        let queryType = try GraphQLObjectType(
            name: "Query",
            description: "",
            fields: fields
        )

        let scalarType = try GraphQLScalarType(
            name: "SomeScalar",
            description: ""
        )

        let interfaceType = try GraphQLInterfaceType(
            name: "SomeInterface",
            description: "",
            fields: fields
        )

        let unionType = try GraphQLUnionType(
            name: "SomeUnion",
            description: "",
            types: [queryType]
        )

        let enumType = try GraphQLEnumType(
            name: "SomeEnum",
            description: "",
            values: [
                "SOME_VALUE": GraphQLEnumValue(value: "SOME_VALUE", description: ""),
                "ANOTHER_VALUE": GraphQLEnumValue(value: "ANOTHER_VALUE", description: ""),
            ]
        )

        let someDirective = try GraphQLDirective(
            name: "someDirective",
            description: "",
            locations: [DirectiveLocation.query],
            args: args
        )

        let schema = try GraphQLSchema(
            description: "",
            query: queryType,
            types: [scalarType, interfaceType, unionType, enumType],
            directives: [someDirective]
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), #"""
        """"""
        schema {
          query: Query
        }

        """"""
        directive @someDirective(
          """"""
          someArg: String

          """"""
          anotherArg: String
        ) on QUERY

        """"""
        scalar SomeScalar

        """"""
        interface SomeInterface {
          """"""
          someField(
            """"""
            someArg: String

            """"""
            anotherArg: String
          ): String

          """"""
          anotherField(
            """"""
            someArg: String

            """"""
            anotherArg: String
          ): String
        }

        """"""
        union SomeUnion = Query

        """"""
        type Query {
          """"""
          someField(
            """"""
            someArg: String

            """"""
            anotherArg: String
          ): String

          """"""
          anotherField(
            """"""
            someArg: String

            """"""
            anotherArg: String
          ): String
        }

        """"""
        enum SomeEnum {
          """"""
          SOME_VALUE

          """"""
          ANOTHER_VALUE
        }
        """#)
    }

    func testPrintsADescriptionWithOnlyWhitespace() throws {
        let schema = try buildSingleFieldSchema(
            fieldConfig: GraphQLField(
                type: GraphQLString,
                description: " "
            )
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), """
        type Query {
          " "
          singleField: String
        }
        """)
    }

    func testOneLinePrintsAShortDescription() throws {
        let schema = try buildSingleFieldSchema(
            fieldConfig: GraphQLField(
                type: GraphQLString,
                description: "This field is awesome"
            )
        )
        try XCTAssertEqual(expectPrintedSchema(schema: schema), #"""
        type Query {
          """This field is awesome"""
          singleField: String
        }
        """#)
    }

    func testPrintIntrospectionSchema() throws {
        let schema = try GraphQLSchema()
        XCTAssertEqual(printIntrospectionSchema(schema: schema), #"""
        """
        Directs the executor to include this field or fragment only when the \`if\` argument is true.
        """
        directive @include(
          """Included when true."""
          if: Boolean!
        ) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

        """
        Directs the executor to skip this field or fragment when the \`if\` argument is true.
        """
        directive @skip(
          """Skipped when true."""
          if: Boolean!
        ) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

        """Marks an element of a GraphQL schema as no longer supported."""
        directive @deprecated(
          """
          Explains why this element was deprecated, usually also including a suggestion for how to access supported similar data. Formatted using the Markdown syntax, as specified by [CommonMark](https://commonmark.org/).
          """
          reason: String = "No longer supported"
        ) on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE

        """Exposes a URL that specifies the behavior of this scalar."""
        directive @specifiedBy(
          """The URL that specifies the behavior of this scalar."""
          url: String!
        ) on SCALAR

        """
        Indicates exactly one field must be supplied and this field must not be \`null\`.
        """
        directive @oneOf on INPUT_OBJECT

        """
        A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations.
        """
        type __Schema {
          description: String

          """A list of all types supported by this server."""
          types: [__Type!]!

          """The type that query operations will be rooted at."""
          queryType: __Type!

          """
          If this server supports mutation, the type that mutation operations will be rooted at.
          """
          mutationType: __Type

          """
          If this server support subscription, the type that subscription operations will be rooted at.
          """
          subscriptionType: __Type

          """A list of all directives supported by this server."""
          directives: [__Directive!]!
        }

        """
        The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the \`__TypeKind\` enum.

        Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional \`specifiedByURL\`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
        """
        type __Type {
          kind: __TypeKind!
          name: String
          description: String
          specifiedByURL: String
          fields(includeDeprecated: Boolean = false): [__Field!]
          interfaces: [__Type!]
          possibleTypes: [__Type!]
          enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
          inputFields(includeDeprecated: Boolean = false): [__InputValue!]
          ofType: __Type
          isOneOf: Boolean
        }

        """An enum describing what kind of type a given \`__Type\` is."""
        enum __TypeKind {
          """Indicates this type is a scalar."""
          SCALAR

          """
          Indicates this type is an object. \`fields\` and \`interfaces\` are valid fields.
          """
          OBJECT

          """
          Indicates this type is an interface. \`fields\`, \`interfaces\`, and \`possibleTypes\` are valid fields.
          """
          INTERFACE

          """Indicates this type is a union. \`possibleTypes\` is a valid field."""
          UNION

          """Indicates this type is an enum. \`enumValues\` is a valid field."""
          ENUM

          """
          Indicates this type is an input object. \`inputFields\` is a valid field.
          """
          INPUT_OBJECT

          """Indicates this type is a list. \`ofType\` is a valid field."""
          LIST

          """Indicates this type is a non-null. \`ofType\` is a valid field."""
          NON_NULL
        }

        """
        Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type.
        """
        type __Field {
          name: String!
          description: String
          args(includeDeprecated: Boolean = false): [__InputValue!]!
          type: __Type!
          isDeprecated: Boolean!
          deprecationReason: String
        }

        """
        Arguments provided to Fields or Directives and the input fields of an InputObject are represented as Input Values which describe their type and optionally a default value.
        """
        type __InputValue {
          name: String!
          description: String
          type: __Type!

          """
          A GraphQL-formatted string representing the default value for this input value.
          """
          defaultValue: String
          isDeprecated: Boolean!
          deprecationReason: String
        }

        """
        One possible value for a given Enum. Enum values are unique values, not a placeholder for a string or numeric value. However an Enum value is returned in a JSON response as a string.
        """
        type __EnumValue {
          name: String!
          description: String
          isDeprecated: Boolean!
          deprecationReason: String
        }

        """
        A Directive provides a way to describe alternate runtime execution and type validation behavior in a GraphQL document.

        In some cases, you need to provide options to alter GraphQL's execution behavior in ways field arguments will not suffice, such as conditionally including or skipping a field. Directives provide this by describing additional information to the executor.
        """
        type __Directive {
          name: String!
          description: String
          isRepeatable: Boolean!
          locations: [__DirectiveLocation!]!
          args(includeDeprecated: Boolean = false): [__InputValue!]!
        }

        """
        A Directive can be adjacent to many parts of the GraphQL language, a __DirectiveLocation describes one such possible adjacencies.
        """
        enum __DirectiveLocation {
          """Location adjacent to a query operation."""
          QUERY

          """Location adjacent to a mutation operation."""
          MUTATION

          """Location adjacent to a subscription operation."""
          SUBSCRIPTION

          """Location adjacent to a field."""
          FIELD

          """Location adjacent to a fragment definition."""
          FRAGMENT_DEFINITION

          """Location adjacent to a fragment spread."""
          FRAGMENT_SPREAD

          """Location adjacent to an inline fragment."""
          INLINE_FRAGMENT

          """Location adjacent to an operation variable definition."""
          VARIABLE_DEFINITION

          """Location adjacent to a fragment variable definition."""
          FRAGMENT_VARIABLE_DEFINITION

          """Location adjacent to a schema definition."""
          SCHEMA

          """Location adjacent to a scalar definition."""
          SCALAR

          """Location adjacent to an object type definition."""
          OBJECT

          """Location adjacent to a field definition."""
          FIELD_DEFINITION

          """Location adjacent to an argument definition."""
          ARGUMENT_DEFINITION

          """Location adjacent to an interface definition."""
          INTERFACE

          """Location adjacent to a union definition."""
          UNION

          """Location adjacent to an enum definition."""
          ENUM

          """Location adjacent to an enum value definition."""
          ENUM_VALUE

          """Location adjacent to an input object type definition."""
          INPUT_OBJECT

          """Location adjacent to an input object field definition."""
          INPUT_FIELD_DEFINITION
        }
        """#)
    }

    func testPrintsViralSchemaCorrectly() throws {
        let Mutation = try GraphQLObjectType(
            name: "Mutation",
            fields: [
                "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
                "geneSequence": GraphQLField(type: GraphQLNonNull(GraphQLString)),
            ]
        )

        let Virus = try GraphQLObjectType(
            name: "Virus",
            fields: [
                "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
                "knownMutations": GraphQLField(
                    type: GraphQLNonNull(GraphQLList(GraphQLNonNull(Mutation)))
                ),
            ]
        )

        let Query = try GraphQLObjectType(
            name: "Query",
            fields: [
                "viruses": GraphQLField(type: GraphQLList(GraphQLNonNull(Virus))),
            ]
        )

        let viralSchema = try GraphQLSchema(query: Query)
        XCTAssertEqual(
            printSchema(schema: viralSchema),
            """
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
            """
        )
    }
}
