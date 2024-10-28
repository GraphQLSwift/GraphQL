@testable import GraphQL
import XCTest

class GraphQLSchemaTests: XCTestCase {
    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasRequiredArgumentsFromInterface(
    ) throws {
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
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean)),
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
                        "arg3": GraphQLArgument(type: GraphQLNonNull(GraphQLBoolean)),
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { _, _, _ -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasRequiredArgumentMissingInInterfaceButHasDefaultValue(
    ) throws {
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
                        ),
                    ]
                ),
            ],
            interfaces: [interface],
            isTypeOf: { _, _, _ -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertObjectImplementsInterfacePassesWhenObjectFieldHasNullableArgumentMissingInInterface(
    ) throws {
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
            isTypeOf: { _, _, _ -> Bool in
                preconditionFailure("Should not be called")
            }
        )

        _ = try GraphQLSchema(query: object, types: [interface, object])
    }

    func testAssertSchemaCircularReference() throws {
        let object1 = try GraphQLObjectType(
            name: "Object1"
        )
        let object2 = try GraphQLObjectType(
            name: "Object2"
        )
        object1.fields = { [weak object2] in
            guard let object2 = object2 else {
                return [:]
            }
            return [
                "object2": GraphQLField(
                    type: object2
                ),
            ]
        }
        object2.fields = { [weak object1] in
            guard let object1 = object1 else {
                return [:]
            }
            return [
                "object1": GraphQLField(
                    type: object1
                ),
            ]
        }
        let query = try GraphQLObjectType(
            name: "Query",
            fields: [
                "object1": GraphQLField(type: object1),
                "object2": GraphQLField(type: object2),
            ]
        )

        XCTAssertNoThrow(
            try GraphQLSchema(query: query, types: [object1, object2])
        )
    }
}
