@testable import GraphQL
import Testing

class UniqueInputFieldNamesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = UniqueInputFieldNamesRule
    }

    @Test func inputObjectWithFields() throws {
        try assertValid(
            """
            {
              field(arg: { f: true })
            }
            """
        )
    }

    @Test func sameInputObjectWithinTwoArgs() throws {
        try assertValid(
            """
            {
              field(arg1: { f: true }, arg2: { f: true })
            }
            """
        )
    }

    @Test func multipleInputObjectFields() throws {
        try assertValid(
            """
            {
              field(arg: { f1: "value", f2: "value", f3: "value" })
            }
            """
        )
    }

    @Test func allowsForNestedInputObjectsWithSimilarFields() throws {
        try assertValid(
            """
            {
              field(arg: {
                deep: {
                  deep: {
                    id: 1
                  }
                  id: 1
                }
                id: 1
              })
            }
            """
        )
    }

    @Test func duplicateInputObjectFields() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field(arg: { f1: "value", f1: "value" })
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 16),
                (line: 2, column: 29),
            ],
            message: #"There can be only one input field named "f1"."#
        )
    }

    @Test func manyDuplicateInputObjectFields() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            {
              field(arg: { f1: "value", f1: "value", f1: "value" })
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 16),
                (line: 2, column: 29),
            ],
            message: #"There can be only one input field named "f1"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 2, column: 16),
                (line: 2, column: 42),
            ],
            message: #"There can be only one input field named "f1"."#
        )
    }

    @Test func nestedDuplicateInputObjectFields() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              field(arg: { f1: {f2: "value", f2: "value" }})
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 21),
                (line: 2, column: 34),
            ],
            message: #"There can be only one input field named "f2"."#
        )
    }
}
