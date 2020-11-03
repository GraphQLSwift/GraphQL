@testable import GraphQL
import XCTest

class GraphQLArgumentDefinitionTests: XCTestCase {

    func testArgumentWithNullableTypeIsNotARequiredArgument() {
        let argument = GraphQLArgumentDefinition(
            name: "nullableString",
            type: GraphQLString
        )

        XCTAssertFalse(isRequiredArgument(argument))
    }

    func testArgumentWithNonNullTypeIsNotARequiredArgumentWhenItHasADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: .string("Some string")
        )

        XCTAssertFalse(isRequiredArgument(argument))
    }

    func testArgumentWithNonNullArgumentIsARequiredArgumentWhenItDoesNotHaveADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: nil
        )

        XCTAssertTrue(isRequiredArgument(argument))
    }
}
