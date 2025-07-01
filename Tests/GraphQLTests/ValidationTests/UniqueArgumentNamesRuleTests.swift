@testable import GraphQL
import Testing

class UniqueArgumentNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueArgumentNamesRule
    }

    @Test func testNoArgumentsOnField() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    @Test func testNoArgumentsOnDirective() throws {
        try assertValid(
            """
            {
              field @directive
            }
            """
        )
    }

    @Test func testArgumentOnField() throws {
        try assertValid(
            """
            {
              field(arg: "value")
            }
            """
        )
    }

    @Test func testArgumentOnDirective() throws {
        try assertValid(
            """
            {
              field @directive(arg: "value")
            }
            """
        )
    }

    @Test func testSameArgumentOnTwoFields() throws {
        try assertValid(
            """
            {
              one: field(arg: "value")
              two: field(arg: "value")
            }
            """
        )
    }

    @Test func testSameArgumentOnFieldAndDirective() throws {
        try assertValid(
            """
            {
              field(arg: "value") @directive(arg: "value")
            }
            """
        )
    }

    @Test func testSameArgumentOnTwoDirectives() throws {
        try assertValid(
            """
            {
              field @directive1(arg: "value") @directive2(arg: "value")
            }
            """
        )
    }

    @Test func testMultipleFieldArguments() throws {
        try assertValid(
            """
            {
              field(arg1: "value", arg2: "value", arg3: "value")
            }
            """
        )
    }

    @Test func testMultipleDirectiveArguments() throws {
        try assertValid(
            """
            {
              field @directive(arg1: "value", arg2: "value", arg3: "value")
            }
            """
        )
    }

    @Test func testDuplicateFieldArguments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field(arg1: "value", arg1: "value")
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 24),
            ],
            message: "There can be only one argument named \"arg1\"."
        )
    }

    @Test func testManyDuplicateFieldArguments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field(arg1: "value", arg1: "value", arg1: "value")
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 9),
                (line: 2, column: 24),
                (line: 2, column: 39),
            ],
            message: "There can be only one argument named \"arg1\"."
        )
    }

    @Test func testDuplicateDirectiveArguments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field @directive(arg1: "value", arg1: "value")
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 20),
                (line: 2, column: 35),
            ],
            message: "There can be only one argument named \"arg1\"."
        )
    }

    @Test func testManyDuplicateDirectiveArguments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field @directive(arg1: "value", arg1: "value", arg1: "value")
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 20),
                (line: 2, column: 35),
                (line: 2, column: 50),
            ],
            message: "There can be only one argument named \"arg1\"."
        )
    }
}
