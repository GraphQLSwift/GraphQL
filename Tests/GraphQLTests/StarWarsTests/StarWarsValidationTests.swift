import XCTest
@testable import GraphQL

/**
 * Helper function to test a query and the expected response.
 */
func validationErrors(query: String) throws -> [GraphQLError] {
    let source = Source(body: query, name: "StarWars.graphql")
    let ast = try parse(source: source)
    return validate(schema: StarWarsSchema, ast: ast)
}

class StarWarsValidationTests : XCTestCase {
    func testNestedQueryWithFragment() throws {
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

        XCTAssert(try validationErrors(query: query).isEmpty)
    }

    func testHeroSpaceshipQuery() throws {
        let query = "query HeroSpaceshipQuery {" +
                    "    hero {" +
                    "        favoriteSpaceship" +
                    "    }" +
                    "}" +
                    "fragment NameAndAppearances on Character {" +
                    "    name" +
                    "    appearsIn" +
                    "}"

        XCTAssertFalse(try validationErrors(query: query).isEmpty)
    }

    func testHeroNoFieldsQuery() throws {
        let query = "query HeroNoFieldsQuery {" +
                    "    hero" +
                    "}"

        XCTAssertFalse(try validationErrors(query: query).isEmpty)
    }

    func testHeroFieldsOnScalarQuery() throws {
        let query = "query HeroFieldsOnScalarQuery {" +
                    "    hero {" +
                    "        name {" +
                    "            firstCharacterOfName" +
                    "        }" +
                    "    }" +
                    "}"

        XCTAssertFalse(try validationErrors(query: query).isEmpty)
    }

    func testDroidFieldOnCharacter() throws {
        let query = "query DroidFieldOnCharacter {" +
                    "    hero {" +
                    "        name" +
                    "        primaryFunction" +
                    "    }" +
                    "}"

        XCTAssertFalse(try validationErrors(query: query).isEmpty)
    }

    func testDroidFieldInFragment() throws {
        let query = "query DroidFieldInFragment {" +
                    "    hero {" +
                    "        name" +
                    "        ...DroidFields" +
                    "    }" +
                    "}" +
                    "fragment DroidFields on Droid {" +
                    "    primaryFunction" +
                    "}"

        XCTAssert(try validationErrors(query: query).isEmpty)
    }

    func testDroidFieldInInlineFragment() throws {
        let query = "query DroidFieldInInlineFragment {" +
                    "    hero {" +
                    "        name" +
                    "        ... on Droid {" +
                    "            primaryFunction" +
                    "        }" +
                    "    }" +
                    "}"

        XCTAssert(try validationErrors(query: query).isEmpty)
    }
}

extension StarWarsValidationTests {
    static var allTests: [(String, (StarWarsValidationTests) -> () throws -> Void)] {
        return [
            ("testNestedQueryWithFragment", testNestedQueryWithFragment),
            ("testHeroSpaceshipQuery", testHeroSpaceshipQuery),
            ("testHeroNoFieldsQuery", testHeroNoFieldsQuery),
            ("testHeroFieldsOnScalarQuery", testHeroFieldsOnScalarQuery),
            ("testDroidFieldOnCharacter", testDroidFieldOnCharacter),
            ("testDroidFieldInFragment", testDroidFieldInFragment),
            ("testDroidFieldInInlineFragment", testDroidFieldInInlineFragment),
        ]
    }
}
