@testable import GraphQL
import Testing

class UniqueArgumentNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueArgumentNamesRule
    }

    @Test func noArgumentsOnField() throws {
        try assertValid(
            """
            {
              field
            }
            """
        )
    }

    @Test func noArgumentsOnDirective() throws {
        try assertValid(
            """
            {
              field @directive
            }
            """
        )
    }

    @Test func argumentOnField() throws {
        try assertValid(
            """
            {
              field(arg: "value")
            }
            """
        )
    }

    @Test func argumentOnDirective() throws {
        try assertValid(
            """
            {
              field @directive(arg: "value")
            }
            """
        )
    }

    @Test func sameArgumentOnTwoFields() throws {
        try assertValid(
            """
            {
              one: field(arg: "value")
              two: field(arg: "value")
            }
            """
        )
    }

    @Test func sameArgumentOnFieldAndDirective() throws {
        try assertValid(
            """
            {
              field(arg: "value") @directive(arg: "value")
            }
            """
        )
    }

    @Test func sameArgumentOnTwoDirectives() throws {
        try assertValid(
            """
            {
              field @directive1(arg: "value") @directive2(arg: "value")
            }
            """
        )
    }

    @Test func multipleFieldArguments() throws {
        try assertValid(
            """
            {
              field(arg1: "value", arg2: "value", arg3: "value")
            }
            """
        )
    }

    @Test func multipleDirectiveArguments() throws {
        try assertValid(
            """
            {
              field @directive(arg1: "value", arg2: "value", arg3: "value")
            }
            """
        )
    }

    @Test func duplicateFieldArguments() throws {
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

    @Test func manyDuplicateFieldArguments() throws {
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

    @Test func duplicateDirectiveArguments() throws {
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

    @Test func manyDuplicateDirectiveArguments() throws {
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
