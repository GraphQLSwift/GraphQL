@testable import GraphQL
import Testing

class NoUnusedVariablesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = NoUnusedVariablesRule
    }

    @Test func usesAllVariables() throws {
        try assertValid(
            """
            query ($a: String, $b: String, $c: String) {
                field(a: $a, b: $b, c: $c)
            }
            """
        )
    }

    @Test func usesAllVariablesDeeply() throws {
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

    @Test func usesAllVariablesDeeplyInInlineFragments() throws {
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

    @Test func usesAllVariablesInFragments() throws {
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

    @Test func variableUsedByFragmentInMultipleOperations() throws {
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

    @Test func variableUsedByRecursiveFragment() throws {
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

    @Test func variableNotUsed() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query ($a: String, $b: String, $c: String) {
                field(a: $a, b: $b)
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 32,
            message: "Variable \"$c\" is never used."
        )
    }

    @Test func multipleVariablesNotUsed() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($a: String, $b: String, $c: String) {
                field(b: $b)
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 1, column: 11,
            message: #"Variable "$a" is never used in operation "Foo"."#
        )

        try assertValidationError(
            error: errors[1], line: 1, column: 35,
            message: #"Variable "$c" is never used in operation "Foo"."#
        )
    }

    @Test func variableNotUsedInFragments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
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
                field
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 35,
            message: #"Variable "$c" is never used in operation "Foo"."#
        )
    }

    @Test func multipleVariablesNotUsedInFragments() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo($a: String, $b: String, $c: String) {
                ...FragA
            }
            fragment FragA on Type {
                field {
                    ...FragB
                }
            }
            fragment FragB on Type {
                field(b: $b) {
                    ...FragC
                }
            }
            fragment FragC on Type {
                field
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 1, column: 11,
            message: #"Variable "$a" is never used in operation "Foo"."#
        )

        try assertValidationError(
            error: errors[1], line: 1, column: 35,
            message: #"Variable "$c" is never used in operation "Foo"."#
        )
    }

    @Test func variableNotUsedByUnreferencedFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query Foo($b: String) {
                ...FragA
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
            error: errors.first, line: 1, column: 11,
            message: #"Variable "$b" is never used in operation "Foo"."#
        )
    }

    @Test func variableNotUsedByFragmentUsedByOtherOperation() throws {
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
            error: errors[0], line: 1, column: 11,
            message: #"Variable "$b" is never used in operation "Foo"."#
        )

        try assertValidationError(
            error: errors[1], line: 4, column: 11,
            message: #"Variable "$a" is never used in operation "Bar"."#
        )
    }

    @Test func variableUsedInsideObject() throws {
        try assertValid(
            """
            query Foo($a: String) {
              field(object: { a: $a })
            }
            """
        )
    }

    @Test func variableUnusedInsideObject() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query Foo($a: String, $b: String) {
              field(object: { a: $a })
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 1, column: 23,
            message: #"Variable "$b" is never used in operation "Foo"."#
        )
    }
}
