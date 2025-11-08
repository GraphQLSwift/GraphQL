@testable import GraphQL
import Testing

class NoUndefinedVariablesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = NoUndefinedVariablesRule
    }

    @Test func allVariablesDefined() throws {
        try assertValid(
            """
            query Foo($a: String, $b: String, $c: String) {
              field(a: $a, b: $b, c: $c)
            }
            """
        )
    }

    @Test func allVariablesDeeplyDefined() throws {
        try assertValid(
            """
            query Foo($a: String, $b: String, $c: String) {
              field(a: $a) {
                field(b: $b) {
                  field(c: $c)
                }
              }
            }
            """
        )
    }

    @Test func allVariablesDeeplyInInlineFragmentsDefined() throws {
        try assertValid(
            """
            query Foo($a: String, $b: String, $c: String) {
              ... on Type {
                field(a: $a) {
                  field(b: $b) {
                    ... on Type {
                      field(c: $c)
                    }
                  }
                }
              }
            }
            """
        )
    }

    @Test func allVariablesInFragmentsDeeplyDefined() throws {
        try assertValid(
            """
            query Foo($a: String, $b: String, $c: String) {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a) {
                ...FragB
              }
            }
            fragment FragB on Type {
              field(b: $b) {
                ...FragC
              }
            }
            fragment FragC on Type {
              field(c: $c)
            }
            """
        )
    }

    @Test func variableWithinSingleFragmentDefinedInMultipleOperations() throws {
        try assertValid(
            """
            query Foo($a: String) {
              ...FragA
            }
            query Bar($a: String) {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a)
            }
            """
        )
    }

    @Test func variableWithinFragmentsDefinedInOperations() throws {
        try assertValid(
            """
            query Foo($a: String) {
              ...FragA
            }
            query Bar($b: String) {
              ...FragB
            }
            fragment FragA on Type {
              field(a: $a)
            }
            fragment FragB on Type {
              field(b: $b)
            }
            """
        )
    }

    @Test func variableWithinRecursiveFragmentDefined() throws {
        try assertValid(
            """
            query Foo($a: String) {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a) {
                ...FragA
              }
            }
            """
        )
    }

    @Test func variableNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query Foo($a: String, $b: String, $c: String) {
              field(a: $a, b: $b, c: $c, d: $d)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 33),
                (line: 1, column: 1),
            ],
            message: #"Variable "$d" is not defined by operation "Foo"."#
        )
    }

    @Test func variableNotDefinedByUnNamedQuery() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              field(a: $a)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined."#
        )
    }

    @Test func multipleVariablesNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($b: String) {
              field(a: $a, b: $b, c: $c)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 2, column: 26),
                (line: 1, column: 1),
            ],
            message: #"Variable "$c" is not defined by operation "Foo"."#
        )
    }

    @Test func variableInFragmentNotDefinedByUnNamedQuery() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 5, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined."#
        )
    }

    @Test func variableInFragmentNotDefinedByOperation() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query Foo($a: String, $b: String) {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a) {
                ...FragB
              }
            }
            fragment FragB on Type {
              field(b: $b) {
                ...FragC
              }
            }
            fragment FragC on Type {
              field(c: $c)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 15, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$c" is not defined by operation "Foo"."#
        )
    }

    @Test func multipleVariablesInFragmentsNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($b: String) {
              ...FragA
            }
            fragment FragA on Type {
              field(a: $a) {
                ...FragB
              }
            }
            fragment FragB on Type {
              field(b: $b) {
                ...FragC
              }
            }
            fragment FragC on Type {
              field(c: $c)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 5, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 15, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$c" is not defined by operation "Foo"."#
        )
    }

    @Test func singleVariableInFragmentNotDefinedByMultipleOperations() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($a: String) {
              ...FragAB
            }
            query Bar($a: String) {
              ...FragAB
            }
            fragment FragAB on Type {
              field(a: $a, b: $b)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 8, column: 19),
                (line: 1, column: 1),
            ],
            message: #"Variable "$b" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 8, column: 19),
                (line: 4, column: 1),
            ],
            message: #"Variable "$b" is not defined by operation "Bar"."#
        )
    }

    @Test func singleVariableInFragmentUsedByOtherOperation() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($b: String) {
              ...FragA
            }
            query Bar($a: String) {
              ...FragB
            }
            fragment FragA on Type {
              field(a: $a)
            }
            fragment FragB on Type {
              field(b: $b)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 8, column: 12),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 11, column: 12),
                (line: 4, column: 1),
            ],
            message: #"Variable "$b" is not defined by operation "Bar"."#
        )
    }

    @Test func multipleUndefinedVariablesProduceMultipleErrors() throws {
        let errors = try assertInvalid(
            errorCount: 6,
            query: """
            query Foo($b: String) {
              ...FragAB
            }
            query Bar($a: String) {
              ...FragAB
            }
            fragment FragAB on Type {
              field1(a: $a, b: $b)
              ...FragC
              field3(a: $a, b: $b)
            }
            fragment FragC on Type {
              field2(c: $c)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 8, column: 13),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 10, column: 13),
                (line: 1, column: 1),
            ],
            message: #"Variable "$a" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[2],
            locations: [
                (line: 13, column: 13),
                (line: 1, column: 1),
            ],
            message: #"Variable "$c" is not defined by operation "Foo"."#
        )
        try assertValidationError(
            error: errors[3],
            locations: [
                (line: 8, column: 20),
                (line: 4, column: 1),
            ],
            message: #"Variable "$b" is not defined by operation "Bar"."#
        )
        try assertValidationError(
            error: errors[4],
            locations: [
                (line: 10, column: 20),
                (line: 4, column: 1),
            ],
            message: #"Variable "$b" is not defined by operation "Bar"."#
        )
        try assertValidationError(
            error: errors[5],
            locations: [
                (line: 13, column: 13),
                (line: 4, column: 1),
            ],
            message: #"Variable "$c" is not defined by operation "Bar"."#
        )
    }
}
