@testable import GraphQL
import Testing

/**
 * Helper function to test a query and the expected response.
 */
func validationErrors(query: String) throws -> [GraphQLError] {
    let source = Source(body: query, name: "StarWars.graphql")
    let ast = try parse(source: source)
    return validate(schema: starWarsSchema, ast: ast)
}

@Suite struct StarWarsValidationTests {
    @Test func nestedQueryWithFragment() throws {
        let query = "query NestedQueryWithFragment {" +
            "    hero {" +
            "        ...NameAndAppearances" +
            "        friends {" +
            "            ...NameAndAppearances" +
            "             friends {" +
            "                 ...NameAndAppearances" +
            "             }" +
            "        }" +
            "    }" +
            "}" +
            "fragment NameAndAppearances on Character {" +
            "    name" +
            "    appearsIn" +
            "}"

        #expect(try validationErrors(query: query).isEmpty)
    }

    @Test func heroSpaceshipQuery() throws {
        let query = "query HeroSpaceshipQuery {" +
            "    hero {" +
            "        favoriteSpaceship" +
            "    }" +
            "}" +
            "fragment NameAndAppearances on Character {" +
            "    name" +
            "    appearsIn" +
            "}"

        #expect(try !validationErrors(query: query).isEmpty)
    }

    @Test func heroNoFieldsQuery() throws {
        let query = "query HeroNoFieldsQuery {" +
            "    hero" +
            "}"

        #expect(try !validationErrors(query: query).isEmpty)
    }

    @Test func heroFieldsOnScalarQuery() throws {
        let query = "query HeroFieldsOnScalarQuery {" +
            "    hero {" +
            "        name {" +
            "            firstCharacterOfName" +
            "        }" +
            "    }" +
            "}"

        #expect(try !validationErrors(query: query).isEmpty)
    }

    @Test func droidFieldOnCharacter() throws {
        let query = "query DroidFieldOnCharacter {" +
            "    hero {" +
            "        name" +
            "        primaryFunction" +
            "    }" +
            "}"

        #expect(try !validationErrors(query: query).isEmpty)
    }

    @Test func droidFieldInFragment() throws {
        let query = "query DroidFieldInFragment {" +
            "    hero {" +
            "        name" +
            "        ...DroidFields" +
            "    }" +
            "}" +
            "fragment DroidFields on Droid {" +
            "    primaryFunction" +
            "}"

        #expect(try validationErrors(query: query).isEmpty)
    }

    @Test func droidFieldInInlineFragment() throws {
        let query = "query DroidFieldInInlineFragment {" +
            "    hero {" +
            "        name" +
            "        ... on Droid {" +
            "            primaryFunction" +
            "        }" +
            "    }" +
            "}"

        #expect(try validationErrors(query: query).isEmpty)
    }
}
