@testable import GraphQL
import Testing

let SomeSchema = try! buildSchema(source: """
scalar SomeScalar

interface SomeInterface { f: SomeObject }

type SomeObject implements SomeInterface { f: SomeObject }

union SomeUnion = SomeObject

enum SomeEnum { ONLY }

input SomeInputObject { val: String = "hello" }

directive @SomeDirective on QUERY
""")
let SomeScalarType = SomeSchema.getType(name: "SomeScalar") as! GraphQLScalarType
let SomeInterfaceType = SomeSchema.getType(name: "SomeInterface") as! GraphQLInterfaceType
let SomeObjectType = SomeSchema.getType(name: "SomeObject") as! GraphQLObjectType
let SomeUnionType = SomeSchema.getType(name: "SomeUnion") as! GraphQLUnionType
let SomeEnumType = SomeSchema.getType(name: "SomeEnum") as! GraphQLEnumType
let SomeInputObjectType = SomeSchema.getType(name: "SomeInputObject") as! GraphQLInputObjectType
let SomeDirective = SomeSchema.getDirective(name: "SomeDirective")

let outputTypes: [GraphQLOutputType] = [
    GraphQLString, GraphQLList(GraphQLString), GraphQLNonNull(GraphQLString),
    GraphQLNonNull(GraphQLList(GraphQLString)),
    SomeScalarType, GraphQLList(SomeScalarType), GraphQLNonNull(SomeScalarType),
    GraphQLNonNull(GraphQLList(SomeScalarType)),
    SomeEnumType, GraphQLList(SomeEnumType), GraphQLNonNull(SomeEnumType),
    GraphQLNonNull(GraphQLList(SomeEnumType)),
    SomeObjectType, GraphQLList(SomeObjectType), GraphQLNonNull(SomeObjectType),
    GraphQLNonNull(GraphQLList(SomeObjectType)),
    SomeUnionType, GraphQLList(SomeUnionType), GraphQLNonNull(SomeUnionType),
    GraphQLNonNull(GraphQLList(SomeUnionType)),
    SomeInterfaceType, GraphQLList(SomeInterfaceType), GraphQLNonNull(SomeInterfaceType),
    GraphQLNonNull(GraphQLList(SomeInterfaceType)),
]
let notOutputTypes: [GraphQLInputType] = [
    SomeInputObjectType, GraphQLList(SomeInputObjectType), GraphQLNonNull(SomeInputObjectType),
    GraphQLNonNull(GraphQLList(SomeInputObjectType)),
]
let inputTypes: [GraphQLInputType] = [
    GraphQLString, GraphQLList(GraphQLString), GraphQLNonNull(GraphQLString),
    GraphQLNonNull(GraphQLList(GraphQLString)),
    SomeScalarType, GraphQLList(SomeScalarType), GraphQLNonNull(SomeScalarType),
    GraphQLNonNull(GraphQLList(SomeScalarType)),
    SomeEnumType, GraphQLList(SomeEnumType), GraphQLNonNull(SomeEnumType),
    GraphQLNonNull(GraphQLList(SomeEnumType)),
    SomeInputObjectType, GraphQLList(SomeInputObjectType), GraphQLNonNull(SomeInputObjectType),
    GraphQLNonNull(GraphQLList(SomeInputObjectType)),
]
let notInputTypes: [GraphQLOutputType] = [
    SomeObjectType, GraphQLList(SomeObjectType), GraphQLNonNull(SomeObjectType),
    GraphQLNonNull(GraphQLList(SomeObjectType)),
    SomeUnionType, GraphQLList(SomeUnionType), GraphQLNonNull(SomeUnionType),
    GraphQLNonNull(GraphQLList(SomeUnionType)),
    SomeInterfaceType, GraphQLList(SomeInterfaceType), GraphQLNonNull(SomeInterfaceType),
    GraphQLNonNull(GraphQLList(SomeInterfaceType)),
]

func schemaWithFieldType(type: GraphQLOutputType) throws -> GraphQLSchema {
    return try GraphQLSchema(
        query: GraphQLObjectType(
            name: "Query",
            fields: [
                "f": .init(type: type),
            ]
        )
    )
}

@Suite struct ValidateSchemaTests {
    // MARK: Type System: A Schema must have Object root types

    @Test func acceptsASchemaWhoseQueryTypeIsAnObjectType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])

        let schemaWithDef = try buildSchema(source: """
          schema {
            query: QueryRoot
          }

          type QueryRoot {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schemaWithDef) == [])
    }

    @Test func acceptsASchemaWhoseQueryAndMutationTypesAreObjectTypes() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: String
          }

          type Mutation {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])

        let schemaWithDef = try buildSchema(source: """
          schema {
            query: QueryRoot
            mutation: MutationRoot
          }

          type QueryRoot {
            test: String
          }

          type MutationRoot {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schemaWithDef) == [])
    }

    @Test func acceptsASchemaWhoseQueryAndSubscriptionTypesAreObjectTypes() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: String
          }

          type Subscription {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])

        let schemaWithDef = try buildSchema(source: """
          schema {
            query: QueryRoot
            subscription: SubscriptionRoot
          }

          type QueryRoot {
            test: String
          }

          type SubscriptionRoot {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schemaWithDef) == [])
    }

    @Test func rejectsASchemaWithoutAQueryType() throws {
        let schema = try buildSchema(source: """
          type Mutation {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(message: "Query root type must be provided."),
        ])

        let schemaWithDef = try buildSchema(source: """
          schema {
            mutation: MutationRoot
          }

          type MutationRoot {
            test: String
          }
        """)
        try #expect(validateSchema(schema: schemaWithDef) == [
            GraphQLError(
                message: "Query root type must be provided.",
                locations: [.init(line: 2, column: 7)]
            ),
        ])
    }

    @Test func rejectsASchemaWhoseQueryRootTypeIsNotAnObjectType() throws {
        #expect(
            throws: (any Error).self,
            "Query root type must be Object type, it cannot be Query."
        ) {
            try buildSchema(source: """
              input Query {
                test: String
              }
            """)
        }

        #expect(
            throws: (any Error).self,
            "Query root type must be Object type, it cannot be SomeInputObject."
        ) {
            try buildSchema(source: """
              schema {
                query: SomeInputObject
              }

              input SomeInputObject {
                test: String
              }
            """)
        }
    }

    @Test func rejectsASchemaWhoseMutationTypeIsAnInputType() throws {
        #expect(
            throws: (any Error).self,
            "Mutation root type must be Object type if provided, it cannot be Mutation."
        ) {
            try buildSchema(source: """
              type Query {
                field: String
              }

              input Mutation {
                test: String
              }
            """)
        }

        #expect(
            throws: (any Error).self,
            "Mutation root type must be Object type if provided, it cannot be SomeInputObject."
        ) {
            try buildSchema(source: """
              schema {
                query: Query
                mutation: SomeInputObject
              }

              type Query {
                field: String
              }

              input SomeInputObject {
                test: String
              }
            """)
        }
    }

    @Test func rejectsASchemaWhoseSubscriptionTypeIsAnInputType() throws {
        #expect(
            throws: (any Error).self,
            "Subscription root type must be Object type if provided, it cannot be Subscription."
        ) {
            try buildSchema(source: """
              type Query {
                field: String
              }

              input Subscription {
                test: String
              }
            """)
        }

        #expect(
            throws: (any Error).self,
            "Subscription root type must be Object type if provided, it cannot be SomeInputObject."
        ) {
            try buildSchema(source: """
              schema {
                query: Query
                subscription: SomeInputObject
              }

              type Query {
                field: String
              }

              input SomeInputObject {
                test: String
              }
            """)
        }
    }

    @Test func rejectsASchemaExtendedWithInvalidRootTypes() throws {
        let schema = try buildSchema(source: """
          input SomeInputObject {
            test: String
          }

          scalar SomeScalar

          enum SomeEnum {
            ENUM_VALUE
          }
        """)

        #expect(
            throws: (any Error).self,
            "Query root type must be Object type, it cannot be SomeInputObject."
        ) {
            try extendSchema(
                schema: schema,
                documentAST: parse(source: """
                  extend schema {
                    query: SomeInputObject
                  }
                """)
            )
        }

        #expect(
            throws: (any Error).self,
            "Mutation root type must be Object type if provided, it cannot be SomeScalar."
        ) {
            try extendSchema(
                schema: schema,
                documentAST: parse(source: """
                  extend schema {
                    mutation: SomeScalar
                  }
                """)
            )
        }

        #expect(
            throws: (any Error).self,
            "Subscription root type must be Object type if provided, it cannot be SomeEnum."
        ) {
            try extendSchema(
                schema: schema,
                documentAST: parse(source: """
                  extend schema {
                    subscription: SomeEnum
                  }
                """)
            )
        }
    }

    @Test func rejectsASchemaWhoseDirectivesHaveEmptyLocations() throws {
        let badDirective = try GraphQLDirective(
            name: "BadDirective",
            locations: [],
            args: [:]
        )
        let schema = try GraphQLSchema(
            query: SomeObjectType,
            directives: [badDirective]
        )
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(message: "Directive @BadDirective must include 1 or more locations."),
        ])
    }

    // MARK: Type System: Root types must all be different if provided

    @Test func acceptsASchemaWithDifferentRootTypes() throws {
        let schema = try buildSchema(source: """
          type SomeObject1 {
            field: String
          }

          type SomeObject2 {
            field: String
          }

          type SomeObject3 {
            field: String
          }

          schema {
            query: SomeObject1
            mutation: SomeObject2
            subscription: SomeObject3
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsASchemaWhereTheSameTypeIsUsedForMultipleRootTypes() throws {
        let schema = try buildSchema(source: """
          type SomeObject {
            field: String
          }

          type UniqueObject {
            field: String
          }

          schema {
            query: SomeObject
            mutation: UniqueObject
            subscription: SomeObject
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "All root types must be different, \"SomeObject\" type is used as query and subscription root types.",
                locations: [
                    .init(line: 11, column: 16),
                    .init(line: 13, column: 23),
                ]
            ),
        ])
    }

    @Test func rejectsASchemaWhereTheSameTypeIsUsedForAllRootTypes() throws {
        let schema = try buildSchema(source: """
          type SomeObject {
            field: String
          }

          schema {
            query: SomeObject
            mutation: SomeObject
            subscription: SomeObject
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "All root types must be different, \"SomeObject\" type is used as query, mutation, and subscription root types.",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 8, column: 19),
                    .init(line: 9, column: 23),
                ]
            ),
        ])
    }

    // MARK: Type System: Objects must have fields

    @Test func acceptsAnObjectTypeWithFieldsObject() throws {
        let schema = try buildSchema(source: """
          type Query {
            field: SomeObject
          }

          type SomeObject {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnObjectTypeWithMissingFields() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: IncompleteObject
          }

          type IncompleteObject
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Type IncompleteObject must define one or more fields.",
                locations: [.init(line: 6, column: 7)]
            ),
        ])

        let manualSchema = try schemaWithFieldType(
            type: GraphQLObjectType(
                name: "IncompleteObject",
                fields: [:]
            )
        )
        try #expect(validateSchema(schema: manualSchema) == [
            GraphQLError(message: "Type IncompleteObject must define one or more fields."),
        ])

        let manualSchema2 = try schemaWithFieldType(
            type:
            GraphQLObjectType(
                name: "IncompleteObject",
                fields: {
                    [:]
                }
            )
        )
        try #expect(validateSchema(schema: manualSchema2) == [
            GraphQLError(message: "Type IncompleteObject must define one or more fields."),
        ])
    }

    @Test func rejectsAnObjectTypeWithIncorrectlyNamedFields() throws {
        let schema = try schemaWithFieldType(
            type:
            GraphQLObjectType(
                name: "SomeObject",
                fields: {
                    ["__badName": .init(type: GraphQLString)]
                }
            )
        )
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Name \"__badName\" must not begin with \"__\", which is reserved by GraphQL introspection."
            ),
        ])
    }

    // MARK: Type System: Fields args must be properly named

    @Test func acceptsFieldArgsWithValidNames() throws {
        let schema = try schemaWithFieldType(
            type:
            GraphQLObjectType(
                name: "SomeObject",
                fields: [
                    "goodField": .init(
                        type: GraphQLString,
                        args: [
                            "goodArg": .init(type: GraphQLString),
                        ]
                    ),
                ]
            )
        )
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsFieldArgWithInvalidNames() throws {
        let schema = try schemaWithFieldType(
            type:
            GraphQLObjectType(
                name: "SomeObject",
                fields: [
                    "badField": .init(
                        type: GraphQLString,
                        args: [
                            "__badName": .init(type: GraphQLString),
                        ]
                    ),
                ]
            )
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Name \"__badName\" must not begin with \"__\", which is reserved by GraphQL introspection."
            ),
        ])
    }

    // MARK: Type System: Union types must be valid

    @Test func acceptsAUnionTypeWithMemberTypes() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: GoodUnion
          }

          type TypeA {
            field: String
          }

          type TypeB {
            field: String
          }

          union GoodUnion =
            | TypeA
            | TypeB
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAUnionTypeWithEmptyTypes() throws {
        var schema = try buildSchema(source: """
          type Query {
            test: BadUnion
          }

          union BadUnion
        """)

        schema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              directive @test on UNION

              extend union BadUnion @test
            """)
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Union type BadUnion must define one or more member types.",
                locations: [
                    .init(line: 6, column: 7),
                    .init(line: 4, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsAUnionTypeWithDuplicatedMemberType() throws {
        var schema = try buildSchema(source: """
          type Query {
            test: BadUnion
          }

          type TypeA {
            field: String
          }

          type TypeB {
            field: String
          }

          union BadUnion =
            | TypeA
            | TypeB
            | TypeA
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Union type BadUnion can only include type TypeA once.",
                locations: [
                    .init(line: 15, column: 11),
                    .init(line: 17, column: 11),
                ]
            ),
        ])

        schema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "extend union BadUnion = TypeB")
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Union type BadUnion can only include type TypeA once.",
                locations: [
                    .init(line: 15, column: 11),
                    .init(line: 17, column: 11),
                ]
            ),
            GraphQLError(
                message: "Union type BadUnion can only include type TypeB once.",
                locations: [
                    .init(line: 16, column: 11),
                    .init(line: 1, column: 25),
                ]
            ),
        ])
    }

    // MARK: Type System: Input Objects must have fields

    @Test func acceptsAnInputObjectTypeWithFields() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInputObjectTypeWithMissingFields() throws {
        var schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject
        """)

        schema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              directive @test on INPUT_OBJECT

              extend input SomeInputObject @test
            """)
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Input Object type SomeInputObject must define one or more fields.",
                locations: [
                    .init(line: 6, column: 7),
                    .init(line: 4, column: 9),
                ]
            ),
        ])
    }

    @Test func acceptsAnInputObjectWithBreakableCircularReference() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            self: SomeInputObject
            arrayOfSelf: [SomeInputObject]
            nonNullArrayOfSelf: [SomeInputObject]!
            nonNullArrayOfNonNullSelf: [SomeInputObject!]!
            intermediateSelf: AnotherInputObject
          }

          input AnotherInputObject {
            parent: SomeInputObject
          }
        """)

        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInputObjectWithNonBreakableCircularReference() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            nonNullSelf: SomeInputObject!
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: #"Cannot reference Input Object "SomeInputObject" within itself through a series of non-null fields: "nonNullSelf"."#,
                locations: [.init(line: 7, column: 9)]
            ),
        ])
    }

    @Test func rejectsInputObjectsWithNonbreakableCircularReferenceSpreadAcrossThem() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            startLoop: AnotherInputObject!
          }

          input AnotherInputObject {
            nextInLoop: YetAnotherInputObject!
          }

          input YetAnotherInputObject {
            closeLoop: SomeInputObject!
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                #"Cannot reference Input Object "SomeInputObject" within itself through a series of non-null fields: "startLoop.nextInLoop.closeLoop"."#,
                locations: [
                    .init(line: 7, column: 9),
                    .init(line: 11, column: 9),
                    .init(line: 15, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsInputObjectsWithMultipleNonbreakableCircularReference() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            startLoop: AnotherInputObject!
          }

          input AnotherInputObject {
            closeLoop: SomeInputObject!
            startSecondLoop: YetAnotherInputObject!
          }

          input YetAnotherInputObject {
            closeSecondLoop: AnotherInputObject!
            nonNullSelf: YetAnotherInputObject!
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                #"Cannot reference Input Object "SomeInputObject" within itself through a series of non-null fields: "startLoop.closeLoop"."#,
                locations: [
                    .init(line: 7, column: 9),
                    .init(line: 11, column: 9),
                ]
            ),
            GraphQLError(
                message:
                #"Cannot reference Input Object "AnotherInputObject" within itself through a series of non-null fields: "startSecondLoop.closeSecondLoop"."#,
                locations: [
                    .init(line: 12, column: 9),
                    .init(line: 16, column: 9),
                ]
            ),
            GraphQLError(
                message: #"Cannot reference Input Object "YetAnotherInputObject" within itself through a series of non-null fields: "nonNullSelf"."#,
                locations: [.init(line: 17, column: 9)]
            ),
        ])
    }

    @Test func rejectsAnInputObjectTypeWithIncorrectlyTypedFields() throws {
        #expect(
            throws: (any Error).self,
            "The type of SomeInputObject.badObject must be Input Type but got: SomeObject."
        ) {
            try buildSchema(source: """
              type Query {
                field(arg: SomeInputObject): String
              }

              type SomeObject {
                field: String
              }

              union SomeUnion = SomeObject

              input SomeInputObject {
                badObject: SomeObject
                badUnion: SomeUnion
                goodInputObject: SomeInputObject
              }
            """)
        }
    }

    @Test func rejectsAnInputObjectTypeWithRequiredArgumentThatIsDeprecated() throws {
        let schema = try buildSchema(source: """
          type Query {
            field(arg: SomeInputObject): String
          }

          input SomeInputObject {
            badField: String! @deprecated
            optionalField: String @deprecated
            anotherOptionalField: String! = "" @deprecated
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Required input field SomeInputObject.badField cannot be deprecated.",
                locations: [
                    .init(line: 7, column: 27),
                    .init(line: 7, column: 19),
                ]
            ),
        ])
    }

    // MARK: Type System: Enum types must be well defined

    @Test func rejectsAnEnumTypeWithoutValues() throws {
        var schema = try buildSchema(source: """
          type Query {
            field: SomeEnum
          }

          enum SomeEnum
        """)

        schema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              directive @test on ENUM

              extend enum SomeEnum @test
            """)
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Enum type SomeEnum must define one or more values.",
                locations: [
                    .init(line: 6, column: 7),
                    .init(line: 4, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsAnEnumTypeWithIncorrectlyNamedValues() throws {
        let schema = try schemaWithFieldType(
            type:
            GraphQLEnumType(
                name: "SomeEnum",
                values: [
                    "__badName": .init(value: .string("__badName")),
                ]
            )
        )

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: #"Name "__badName" must not begin with "__", which is reserved by GraphQL introspection."#
            ),
        ])
    }

    // MARK: Type System: Object fields must have output types

    func schemaWithObjectField(
        fieldConfig: GraphQLField
    ) throws -> GraphQLSchema {
        let BadObjectType = try GraphQLObjectType(
            name: "BadObject",
            fields: [
                "badField": fieldConfig,
            ]
        )

        return try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "f": .init(type: BadObjectType),
                ]
            ),
            types: [SomeObjectType]
        )
    }

    @Test func rejectsWithRelevantLocationsForANonoutputTypeAsAnObjectFieldType() throws {
        #expect(
            throws: (any Error).self,
            "The type of Query.field must be Output Type but got: [SomeInputObject]."
        ) {
            try buildSchema(source: """
              type Query {
                field: [SomeInputObject]
              }

              input SomeInputObject {
                field: String
              }
            """)
        }
    }

    // MARK: Type System: Objects can only implement unique interfaces

    @Test func rejectsAnObjectImplementingANoninterfaceType() throws {
        #expect(
            throws: (any Error).self,
            "Type BadObject must only implement Interface types, it cannot implement SomeInputObject."
        ) {
            try buildSchema(source: """
              type Query {
                test: BadObject
              }

              input SomeInputObject {
                field: String
              }

              type BadObject implements SomeInputObject {
                field: String
              }
            """)
        }
    }

    @Test func rejectsAnObjectImplementingTheSameInterfaceTwice() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface & AnotherInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Type AnotherObject can only implement AnotherInterface once.",
                locations: [
                    .init(line: 10, column: 37),
                    .init(line: 10, column: 56),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectImplementingTheSameInterfaceTwiceDueToExtension() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: "extend type AnotherObject implements AnotherInterface")
        )
        try #expect(validateSchema(schema: extendedSchema) == [
            GraphQLError(
                message: "Type AnotherObject can only implement AnotherInterface once.",
                locations: [
                    .init(line: 10, column: 37),
                    .init(line: 1, column: 38),
                ]
            ),
        ])
    }

    // MARK: Type System: Interface extensions should be valid

    @Test func rejectsAnObjectImplementingTheExtendedInterfaceDueToMissingField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              extend interface AnotherInterface {
                newField: String
              }

              extend type AnotherObject {
                differentNewField: String
              }
            """)
        )
        try #expect(validateSchema(schema: extendedSchema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.newField expected but AnotherObject does not provide it.",
                locations: [
                    .init(line: 3, column: 11),
                    .init(line: 10, column: 7),
                    .init(line: 6, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectImplementingTheExtendedInterfaceDueToMissingFieldArgs() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              extend interface AnotherInterface {
                newField(test: Boolean): String
              }

              extend type AnotherObject {
                newField: String
              }
            """)
        )
        try #expect(validateSchema(schema: extendedSchema) == [
            GraphQLError(
                message:
                "Interface field argument AnotherInterface.newField(test:) expected but AnotherObject.newField does not provide it.",
                locations: [
                    .init(line: 3, column: 20),
                    .init(line: 7, column: 11),
                ]
            ),
        ])
    }

    @Test func rejectsObjectsImplementingTheExtendedInterfaceDueToMismatchingInterfaceType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        let extendedSchema = try extendSchema(
            schema: schema,
            documentAST: parse(source: """
              extend interface AnotherInterface {
                newInterfaceField: NewInterface
              }

              interface NewInterface {
                newField: String
              }

              interface MismatchingInterface {
                newField: String
              }

              extend type AnotherObject {
                newInterfaceField: MismatchingInterface
              }

              # Required to prevent unused interface errors
              type DummyObject implements NewInterface & MismatchingInterface {
                newField: String
              }
            """)
        )
        try #expect(validateSchema(schema: extendedSchema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.newInterfaceField expects type NewInterface but AnotherObject.newInterfaceField is type MismatchingInterface.",
                locations: [
                    .init(line: 3, column: 30),
                    .init(line: 15, column: 30),
                ]
            ),
        ])
    }

    // MARK: Type System: Interface fields must have output types

    func schemaWithInterfaceField(
        fieldConfig: GraphQLField
    ) throws -> GraphQLSchema {
        let BadInterfaceType = try GraphQLInterfaceType(
            name: "BadInterface",
            fields: ["badField": fieldConfig]
        )

        let BadImplementingType = try GraphQLObjectType(
            name: "BadImplementing",
            fields: ["badField": fieldConfig],
            interfaces: [BadInterfaceType]
        )

        return try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "f": .init(type: BadInterfaceType),
                ]
            ),
            types: [BadImplementingType, SomeObjectType]
        )
    }

    @Test func acceptsAnOutputTypeAsAnInterfaceFieldType() throws {
        for type in outputTypes {
            let schema = try schemaWithInterfaceField(fieldConfig: .init(type: type))
            try #expect(validateSchema(schema: schema) == [])
        }
    }

    @Test func rejectsANonoutputTypeAsAnInterfaceFieldTypeWithLocations() throws {
        #expect(
            throws: (any Error).self,
            "The type of SomeInterface.field must be Output Type but got: SomeInputObject."
        ) {
            try buildSchema(source: """
              type Query {
                test: SomeInterface
              }

              interface SomeInterface {
                field: SomeInputObject
              }

              input SomeInputObject {
                foo: String
              }

              type SomeObject implements SomeInterface {
                field: SomeInputObject
              }
            """)
        }
    }

    @Test func acceptsAnInterfaceNotImplementedByAtLeastOneObject() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: SomeInterface
          }

          interface SomeInterface {
            foo: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    // MARK: Type System: Arguments must have input types

    func schemaWithArg(argConfig: GraphQLArgument) throws -> GraphQLSchema {
        let BadObjectType = try GraphQLObjectType(
            name: "BadObject",
            fields: [
                "badField": .init(
                    type: GraphQLString,
                    args: [
                        "badArg": argConfig,
                    ]
                ),
            ]
        )

        return try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "f": .init(type: BadObjectType),
                ]
            ),
            directives: [
                GraphQLDirective(
                    name: "BadDirective",
                    locations: [DirectiveLocation.query],
                    args: [
                        "badArg": argConfig,
                    ]
                ),
            ]
        )
    }

    @Test func acceptsAnInputTypeAsAFieldArgType() throws {
        for type in inputTypes {
            let schema = try schemaWithArg(argConfig: .init(type: type))
            try #expect(validateSchema(schema: schema) == [])
        }
    }

    @Test func rejectsARequiredArgumentThatIsDeprecated() throws {
        let schema = try buildSchema(source: """
          directive @BadDirective(
            badArg: String! @deprecated
            optionalArg: String @deprecated
            anotherOptionalArg: String! = "" @deprecated
          ) on FIELD

          type Query {
            test(
              badArg: String! @deprecated
              optionalArg: String @deprecated
              anotherOptionalArg: String! = "" @deprecated
            ): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Required argument @BadDirective(badArg:) cannot be deprecated.",
                locations: [
                    .init(line: 3, column: 25),
                    .init(line: 3, column: 17),
                ]
            ),
            GraphQLError(
                message: "Required argument Query.test(badArg:) cannot be deprecated.",
                locations: [
                    .init(line: 10, column: 27),
                    .init(line: 10, column: 19),
                ]
            ),
        ])
    }

    @Test func rejectsANoninputTypeAsAFieldArgWithLocations() throws {
        #expect(
            throws: (any Error).self,
            "The type of Query.test(arg:) must be Input Type but got: SomeObject."
        ) {
            try buildSchema(source: """
              type Query {
                test(arg: SomeObject): String
              }

              type SomeObject {
                foo: String
              }
            """)
        }
    }

    // MARK: Type System: Input Object fields must have input types

    func schemaWithInputField(
        inputFieldConfig: InputObjectField
    ) throws -> GraphQLSchema {
        let BadInputObjectType = try GraphQLInputObjectType(
            name: "BadInputObject",
            fields: [
                "badField": inputFieldConfig,
            ]
        )

        return try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "f": .init(
                        type: GraphQLString,
                        args: [
                            "badArg": .init(type: BadInputObjectType),
                        ]
                    ),
                ]
            )
        )
    }

    @Test func acceptsAnInputTypeAsAnInputFieldType() throws {
        for type in inputTypes {
            let schema = try schemaWithInputField(inputFieldConfig: .init(type: type))
            try #expect(validateSchema(schema: schema) == [])
        }
    }

    @Test func rejectsANoninputTypeAsAnInputObjectFieldWithLocations() throws {
        #expect(
            throws: (any Error).self,
            "The type of SomeInputObject.foo must be Input Type but got: SomeObject."
        ) {
            try buildSchema(source: """
              type Query {
                test(arg: SomeInputObject): String
              }

              input SomeInputObject {
                foo: SomeObject
              }

              type SomeObject {
                bar: String
              }
            """)
        }
    }

    // MARK: Type System: OneOf Input Object fields must be nullable

    @Test func rejectsNonnullableFields() throws {
        let schema = try buildSchema(source: """
          type Query {
            test(arg: SomeInputObject): String
          }

          input SomeInputObject @oneOf {
            a: String
            b: String!
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "OneOf input field SomeInputObject.b must be nullable.",
                locations: [.init(line: 8, column: 12)]
            ),
        ])
    }

    @Test func rejectsFieldsWithDefaultValues() throws {
        let schema = try buildSchema(source: """
          type Query {
            test(arg: SomeInputObject): String
          }

          input SomeInputObject @oneOf {
            a: String
            b: String = "foo"
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "OneOf input field SomeInputObject.b cannot have a default value.",
                locations: [.init(line: 8, column: 9)]
            ),
        ])
    }

    // MARK: Objects must adhere to Interface they implement

    @Test func acceptsAnObjectWhichImplementsAnInterface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: String): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnObjectWhichImplementsAnInterfaceAlongWithMoreFields() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: String): String
            anotherField: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnObjectWhichImplementsAnInterfaceFieldAlongWithAdditionalOptionalArguments(
    ) throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: String, anotherInput: String): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnObjectMissingAnInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            anotherField: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expected but AnotherObject does not provide it.",
                locations: [
                    .init(line: 7, column: 9),
                    .init(line: 10, column: 7),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWithAnIncorrectlyTypedInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: String): Int
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type String but AnotherObject.field is type Int.",
                locations: [
                    .init(line: 7, column: 31),
                    .init(line: 11, column: 31),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWithADifferentlyTypedInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          type A { foo: String }
          type B { foo: String }

          interface AnotherInterface {
            field: A
          }

          type AnotherObject implements AnotherInterface {
            field: B
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type A but AnotherObject.field is type B.",
                locations: [
                    .init(line: 10, column: 16),
                    .init(line: 14, column: 16),
                ]
            ),
        ])
    }

    @Test func acceptsAnObjectWithASubtypedInterfaceField_Interface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: AnotherInterface
          }

          type AnotherObject implements AnotherInterface {
            field: AnotherObject
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnObjectWithASubtypedInterfaceField_Union() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          type SomeObject {
            field: String
          }

          union SomeUnionType = SomeObject

          interface AnotherInterface {
            field: SomeUnionType
          }

          type AnotherObject implements AnotherInterface {
            field: SomeObject
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnObjectMissingAnInterfaceArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field argument AnotherInterface.field(input:) expected but AnotherObject.field does not provide it.",
                locations: [
                    .init(line: 7, column: 15),
                    .init(line: 11, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWithAnIncorrectlyTypedInterfaceArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: Int): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field argument AnotherInterface.field(input:) expects type String but AnotherObject.field(input:) is type Int.",
                locations: [
                    .init(line: 7, column: 22),
                    .init(line: 11, column: 22),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWithBothAnIncorrectlyTypedFieldAndArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(input: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(input: Int): Int
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type String but AnotherObject.field is type Int.",
                locations: [
                    .init(line: 7, column: 31),
                    .init(line: 11, column: 28),
                ]
            ),
            GraphQLError(
                message:
                "Interface field argument AnotherInterface.field(input:) expects type String but AnotherObject.field(input:) is type Int.",
                locations: [
                    .init(line: 7, column: 22),
                    .init(line: 11, column: 22),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWhichImplementsAnInterfaceFieldAlongWithAdditionalRequiredArguments(
    ) throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field(baseArg: String): String
          }

          type AnotherObject implements AnotherInterface {
            field(
              baseArg: String,
              requiredArg: String!
              optionalArg1: String,
              optionalArg2: String = "",
            ): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                #"Argument "AnotherObject.field(requiredArg:)" must not be required type "String!" if not provided by the Interface field "AnotherInterface.field"."#,
                locations: [
                    .init(line: 13, column: 11),
                    .init(line: 7, column: 9),
                ]
            ),
        ])
    }

    @Test func acceptsAnObjectWithAnEquivalentlyWrappedInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: [String]!
          }

          type AnotherObject implements AnotherInterface {
            field: [String]!
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnObjectWithANonlistInterfaceFieldListType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: [String]
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type [String] but AnotherObject.field is type String.",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectWithAListInterfaceFieldNonlistType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: [String]
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type String but AnotherObject.field is type [String].",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func acceptsAnObjectWithASubsetNonnullInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String
          }

          type AnotherObject implements AnotherInterface {
            field: String!
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnObjectWithASupersetNullableInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface AnotherInterface {
            field: String!
          }

          type AnotherObject implements AnotherInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field AnotherInterface.field expects type String! but AnotherObject.field is type String.",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectMissingATransitiveInterface_Object() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: AnotherObject
          }

          interface SuperInterface {
            field: String!
          }

          interface AnotherInterface implements SuperInterface {
            field: String!
          }

          type AnotherObject implements AnotherInterface {
            field: String!
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Type AnotherObject must implement SuperInterface because it is implemented by AnotherInterface.",
                locations: [
                    .init(line: 10, column: 45),
                    .init(line: 14, column: 37),
                ]
            ),
        ])
    }

    // MARK: Interfaces must adhere to Interface they implement

    @Test func acceptsAnInterfaceWhichImplementsAnInterface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: String): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnInterfaceWhichImplementsAnInterfaceAlongWithMoreFields() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: String): String
            anotherField: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnInterfaceWhichImplementsAnInterfaceFieldAlongWithAdditionalOptionalArguments(
    ) throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: String, anotherInput: String): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInterfaceMissingAnInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            anotherField: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expected but ChildInterface does not provide it.",
                locations: [
                    .init(line: 7, column: 9),
                    .init(line: 10, column: 7),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWithAnIncorrectlyTypedInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: String): Int
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type String but ChildInterface.field is type Int.",
                locations: [
                    .init(line: 7, column: 31),
                    .init(line: 11, column: 31),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWithADifferentlyTypedInterfaceField() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          type A { foo: String }
          type B { foo: String }

          interface ParentInterface {
            field: A
          }

          interface ChildInterface implements ParentInterface {
            field: B
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type A but ChildInterface.field is type B.",
                locations: [
                    .init(line: 10, column: 16),
                    .init(line: 14, column: 16),
                ]
            ),
        ])
    }

    @Test func acceptsAnInterfaceWithASubtypedInterfaceField_Interface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: ParentInterface
          }

          interface ChildInterface implements ParentInterface {
            field: ChildInterface
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func acceptsAnInterfaceWithASubtypedInterfaceField_Union() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          type SomeObject {
            field: String
          }

          union SomeUnionType = SomeObject

          interface ParentInterface {
            field: SomeUnionType
          }

          interface ChildInterface implements ParentInterface {
            field: SomeObject
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInterfaceImplementingANoninterfaceType() throws {
        #expect(
            throws: (any Error).self,
            "Type BadInterface must only implement Interface types, it cannot implement SomeInputObject."
        ) {
            try buildSchema(source: """
              type Query {
                field: String
              }

              input SomeInputObject {
                field: String
              }

              interface BadInterface implements SomeInputObject {
                field: String
              }
            """)
        }
    }

    @Test func rejectsAnInterfaceMissingAnInterfaceArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field argument ParentInterface.field(input:) expected but ChildInterface.field does not provide it.",
                locations: [
                    .init(line: 7, column: 15),
                    .init(line: 11, column: 9),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWithAnIncorrectlyTypedInterfaceArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: Int): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field argument ParentInterface.field(input:) expects type String but ChildInterface.field(input:) is type Int.",
                locations: [
                    .init(line: 7, column: 22),
                    .init(line: 11, column: 22),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWithBothAnIncorrectlyTypedFieldAndArgument() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(input: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(input: Int): Int
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type String but ChildInterface.field is type Int.",
                locations: [
                    .init(line: 7, column: 31),
                    .init(line: 11, column: 28),
                ]
            ),
            GraphQLError(
                message:
                "Interface field argument ParentInterface.field(input:) expects type String but ChildInterface.field(input:) is type Int.",
                locations: [
                    .init(line: 7, column: 22),
                    .init(line: 11, column: 22),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWhichImplementsAnInterfaceFieldAlongWithAdditionalRequiredArguments(
    ) throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field(baseArg: String): String
          }

          interface ChildInterface implements ParentInterface {
            field(
              baseArg: String,
              requiredArg: String!
              optionalArg1: String,
              optionalArg2: String = "",
            ): String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                #"Argument "ChildInterface.field(requiredArg:)" must not be required type "String!" if not provided by the Interface field "ParentInterface.field"."#,
                locations: [
                    .init(line: 13, column: 11),
                    .init(line: 7, column: 9),
                ]
            ),
        ])
    }

    @Test func acceptsAnInterfaceWithAnEquivalentlyWrappedInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: [String]!
          }

          interface ChildInterface implements ParentInterface {
            field: [String]!
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInterfaceWithANonlistInterfaceFieldListType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: [String]
          }

          interface ChildInterface implements ParentInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type [String] but ChildInterface.field is type String.",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func rejectsAnInterfaceWithAListInterfaceFieldNonlistType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: String
          }

          interface ChildInterface implements ParentInterface {
            field: [String]
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type String but ChildInterface.field is type [String].",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func acceptsAnInterfaceWithASubsetNonnullInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: String
          }

          interface ChildInterface implements ParentInterface {
            field: String!
          }
        """)
        try #expect(validateSchema(schema: schema) == [])
    }

    @Test func rejectsAnInterfaceWithASupersetNullableInterfaceFieldType() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface ParentInterface {
            field: String!
          }

          interface ChildInterface implements ParentInterface {
            field: String
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Interface field ParentInterface.field expects type String! but ChildInterface.field is type String.",
                locations: [
                    .init(line: 7, column: 16),
                    .init(line: 11, column: 16),
                ]
            ),
        ])
    }

    @Test func rejectsAnObjectMissingATransitiveInterface_Interface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: ChildInterface
          }

          interface SuperInterface {
            field: String!
          }

          interface ParentInterface implements SuperInterface {
            field: String!
          }

          interface ChildInterface implements ParentInterface {
            field: String!
          }
        """)
        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Type ChildInterface must implement SuperInterface because it is implemented by ParentInterface.",
                locations: [
                    .init(line: 10, column: 44),
                    .init(line: 14, column: 43),
                ]
            ),
        ])
    }

    @Test func rejectsASelfReferenceInterface() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: FooInterface
          }

          interface FooInterface implements FooInterface {
            field: String
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message: "Type FooInterface cannot implement itself because it would create a circular reference.",
                locations: [.init(line: 6, column: 41)]
            ),
        ])
    }

    @Test func rejectsACircularInterfaceImplementation() throws {
        let schema = try buildSchema(source: """
          type Query {
            test: FooInterface
          }

          interface FooInterface implements BarInterface {
            field: String
          }

          interface BarInterface implements FooInterface {
            field: String
          }
        """)

        try #expect(validateSchema(schema: schema) == [
            GraphQLError(
                message:
                "Type FooInterface cannot implement BarInterface because it would create a circular reference.",
                locations: [
                    .init(line: 10, column: 41),
                    .init(line: 6, column: 41),
                ]
            ),
            GraphQLError(
                message:
                "Type BarInterface cannot implement FooInterface because it would create a circular reference.",
                locations: [
                    .init(line: 6, column: 41),
                    .init(line: 10, column: 41),
                ]
            ),
        ])
    }

    // MARK: assertValidSchema

    @Test func doesNotThrowOnValidSchemas() throws {
        let schema = try buildSchema(source: """
          type Query {
            foo: String
          }
        """)
        #expect(throws: Never.self) { try assertValidSchema(schema: schema) }
    }

    @Test func combinesMultipleErrors() throws {
        let schema = try buildSchema(source: "type SomeType")
        #expect(
            throws: (any Error).self,
            """
            Query root type must be provided.

            Type SomeType must define one or more fields.
            """
        ) {
            try assertValidSchema(schema: schema)
        }
    }
}
