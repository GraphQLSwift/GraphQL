@testable import GraphQL
import Testing

class VariablesAreInputTypesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = VariablesAreInputTypesRule
    }

    @Test func testUnknownTypesAreIgnored() throws {
        try assertValid(
            """
            query Foo($a: Unknown, $b: [[Unknown!]]!) {
              field(a: $a, b: $b)
            }
            """
        )
    }

    @Test func testInputTypesAreValid() throws {
        try assertValid(
            """
            query Foo($a: String, $b: [Boolean!]!, $c: ComplexInput) {
              field(a: $a, b: $b, c: $c)
            }
            """
        )
    }

    @Test func testOutputTypesAreInvalid() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            query Foo($a: Dog, $b: [[CatOrDog!]]!, $c: Pet) {
              field(a: $a, b: $b, c: $c)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 15)],
            message: "Variable \"$a\" cannot be non-input type \"Dog\"."
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 1, column: 24)],
            message: "Variable \"$b\" cannot be non-input type \"[[CatOrDog!]]!\"."
        )
        try assertValidationError(
            error: errors[2],
            locations: [(line: 1, column: 44)],
            message: "Variable \"$c\" cannot be non-input type \"Pet\"."
        )
    }
}
