@testable import GraphQL
import Testing

@Suite struct GraphQLArgumentDefinitionTests {
    @Test func testArgumentWithNullableTypeIsNotARequiredArgument() {
        let argument = GraphQLArgumentDefinition(
            name: "nullableString",
            type: GraphQLString
        )

        #expect(!isRequiredArgument(argument))
    }

    @Test func testArgumentWithNonNullTypeIsNotARequiredArgumentWhenItHasADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: .string("Some string")
        )

        #expect(!isRequiredArgument(argument))
    }

    @Test func testArgumentWithNonNullArgumentIsARequiredArgumentWhenItDoesNotHaveADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: nil
        )

        #expect(isRequiredArgument(argument))
    }
}
