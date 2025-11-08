@testable import GraphQL
import Testing

@Suite struct GraphQLArgumentDefinitionTests {
    @Test func argumentWithNullableTypeIsNotARequiredArgument() {
        let argument = GraphQLArgumentDefinition(
            name: "nullableString",
            type: GraphQLString
        )

        #expect(!isRequiredArgument(argument))
    }

    @Test func argumentWithNonNullTypeIsNotARequiredArgumentWhenItHasADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: .string("Some string")
        )

        #expect(!isRequiredArgument(argument))
    }

    @Test func argumentWithNonNullArgumentIsARequiredArgumentWhenItDoesNotHaveADefaultValue() {
        let argument = GraphQLArgumentDefinition(
            name: "nonNullString",
            type: GraphQLNonNull(GraphQLString),
            defaultValue: nil
        )

        #expect(isRequiredArgument(argument))
    }
}
