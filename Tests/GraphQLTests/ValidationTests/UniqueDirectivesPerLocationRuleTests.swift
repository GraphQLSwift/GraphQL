@testable import GraphQL
import Testing

class UniqueDirectivesPerLocationRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueDirectivesPerLocationRule
    }

    @Test func testNoDirectives() throws {
        try assertValid(
            """
            fragment Test on Type {
              field
            }
            """,
            schema: schema
        )
    }

    @Test func testUniqueDirectivesInDifferentLocations() throws {
        try assertValid(
            """
            fragment Test on Type @directiveA {
              field @directiveB
            }
            """,
            schema: schema
        )
    }

    @Test func testUniqueDirectivesInSameLocation() throws {
        try assertValid(
            """
            fragment Test on Type @directiveA @directiveB {
              field @directiveA @directiveB
            }
            """,
            schema: schema
        )
    }

    @Test func testSameDirectivesInDifferentLocations() throws {
        try assertValid(
            """
            fragment Test on Type @directiveA {
              field @directiveA
            }
            """,
            schema: schema
        )
    }

    @Test func testSameDirectivesInSimilarLocations() throws {
        try assertValid(
            """
            fragment Test on Type {
              field @directive
              field @directive
            }
            """,
            schema: schema
        )
    }

    @Test func testRepeatableDirectivesInSameLocation() throws {
        try assertValid(
            """
            fragment Test on Type @repeatable @repeatable {
              field @repeatable @repeatable
            }
            """,
            schema: schema
        )
    }

    @Test func testUnknownDirectivesMustBeIgnored() throws {
        try assertValid(
            """
            type Test @unknown @unknown {
              field: String! @unknown @unknown
            }

            extend type Test @unknown {
              anotherField: String!
            }
            """,
            schema: schema
        )
    }

    @Test func testDuplicateDirectivesInOneLocation() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment Test on Type {
              field @directive @directive
            }
            """,
            schema: schema
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 20),
            ],
            message: #"The directive "@directive" can only be used once at this location."#
        )
    }

    @Test func testManyDuplicateDirectivesInOneLocation() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            fragment Test on Type {
              field @directive @directive @directive
            }
            """,
            schema: schema
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 20),
            ],
            message: #"The directive "@directive" can only be used once at this location."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 31),
            ],
            message: #"The directive "@directive" can only be used once at this location."#
        )
    }

    @Test func testDifferentDuplicateDirectivesInOneLocation() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            fragment Test on Type {
              field @directiveA @directiveB @directiveA @directiveB
            }
            """,
            schema: schema
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 33),
            ],
            message: #"The directive "@directiveA" can only be used once at this location."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 2, column: 21),
                (line: 2, column: 45),
            ],
            message: #"The directive "@directiveB" can only be used once at this location."#
        )
    }

    // TODO: Add SDL tests

    let schema = try! GraphQLSchema(
        query: ValidationExampleQueryRoot,
        types: [
            ValidationExampleCat,
            ValidationExampleDog,
            ValidationExampleHuman,
            ValidationExampleAlien,
        ],
        directives: {
            var directives = specifiedDirectives
            directives.append(contentsOf: [
                ValidationFieldDirective,
                try! GraphQLDirective(name: "directive", locations: [.field, .fragmentDefinition]),
                try! GraphQLDirective(name: "directiveA", locations: [.field, .fragmentDefinition]),
                try! GraphQLDirective(name: "directiveB", locations: [.field, .fragmentDefinition]),
                try! GraphQLDirective(
                    name: "repeatable",
                    locations: [.field, .fragmentDefinition],
                    isRepeatable: true
                ),
            ])
            return directives
        }()
    )
}
