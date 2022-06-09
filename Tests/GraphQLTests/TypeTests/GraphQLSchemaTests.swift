@testable import GraphQL
import XCTest

class GraphQLSchemaTests: XCTestCase {

    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasRequiredArgumentsFromInterface() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithNoArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["requiredArg": GraphQLArgument(type: GraphQLString)]
                ),
                "fieldWithMultipleArgs": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "arg1": GraphQLArgument(type: GraphQLString),
                        "arg2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean))
                    ]
                ),
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithNoArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["requiredArg": GraphQLArgument(type: GraphQLString)]
                ),
                "fieldWithMultipleArgs": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "arg1": GraphQLArgument(type: GraphQLString),
                        "arg2": GraphQLArgument(type: GraphQLNonNull(GraphQLInt)),
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean))
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasRequiredArgumentMissingInInterfaceButHasDefaultValue() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "addedRequiredArgWithDefaultValue": GraphQLArgument(
                            type: GraphQLNonNull(GraphQLInt),
                            defaultValue: .int(5)
                        )
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasNullableArgumentMissingInInterface() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithOneArg": GraphQLField(
                    type: GraphQLInt,
                    args: ["addedNullableArg": GraphQLArgument(type: GraphQLInt)]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertObjectImplementsInterfaceFailsWhenObjectFieldHasRequiredArgumentMissingInInterface() throws {
        let interface = try GraphQLInterfaceType(
            name: "Interface",
            fields: [
                "fieldWithoutArg": GraphQLField(
                    type: GraphQLInt,
                    args: [:]
                ),
            ]
        )

        let object = try GraphQLObjectType(
            name: "Object",
            fields: [
                "fieldWithoutArg": GraphQLField(
                    type: GraphQLInt,
                    args: [
                        "addedRequiredArg": GraphQLArgument(type: GraphQLNonNull(GraphQLInt))
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { (_, _, _) -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        do {
            _ = try GraphQLSchema(query: object, types: [interface, object])
            XCTFail("Expected errors when creating schema")
        } catch {
            let graphQLError = try XCTUnwrap(error as? GraphQLError)
            XCTAssertEqual(graphQLError.message, "Object.fieldWithoutArg includes required argument (addedRequiredArg:) that is missing from the Interface field Interface.fieldWithoutArg.")
        }
    }
    
    func testSubtypingIsReflexive() throws {
        let object = try GraphQLObjectType(
            name: "Object",
            fields: ["foo": GraphQLField(type: GraphQLInt)],
            interfaces: []
        )
        let schema = try GraphQLSchema(query: object, types: [object])
        XCTAssert(schema.isSubType(abstractType: object, maybeSubType: object))
    }
}
