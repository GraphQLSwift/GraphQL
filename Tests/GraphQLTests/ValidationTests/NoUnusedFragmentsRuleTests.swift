@testable import GraphQL
import Testing

class NoUnusedFragmentsRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = NoUnusedFragmentsRule
    }

    @Test func allFragmentNamesAreUsed() throws {
        try assertValid(
            """
            {
              human(id: 4) {
                ...HumanFields1
                ... on Human {
                  ...HumanFields2
                }
              }
            }
            fragment HumanFields1 on Human {
              name
              ...HumanFields3
            }
            fragment HumanFields2 on Human {
              name
            }
            fragment HumanFields3 on Human {
              name
            }
            """
        )
    }

    @Test func allFragmentNamesAreUsedByMultipleOperations() throws {
        try assertValid(
            """
            query Foo {
              human(id: 4) {
                ...HumanFields1
              }
            }
            query Bar {
              human(id: 4) {
                ...HumanFields2
              }
            }
            fragment HumanFields1 on Human {
              name
              ...HumanFields3
            }
            fragment HumanFields2 on Human {
              name
            }
            fragment HumanFields3 on Human {
              name
            }
            """
        )
    }

    @Test func containsUnknownFragments() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo {
              human(id: 4) {
                ...HumanFields1
              }
            }
            query Bar {
              human(id: 4) {
                ...HumanFields2
              }
            }
            fragment HumanFields1 on Human {
              name
              ...HumanFields3
            }
            fragment HumanFields2 on Human {
              name
            }
            fragment HumanFields3 on Human {
              name
            }
            fragment Unused1 on Human {
              name
            }
            fragment Unused2 on Human {
              name
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 21, column: 1,
            message: "Fragment \"Unused1\" is never used."
        )

        try assertValidationError(
            error: errors[1], line: 24, column: 1,
            message: "Fragment \"Unused2\" is never used."
        )
    }

    @Test func containsUnknownFragmentsWithRefCycle() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query Foo {
              human(id: 4) {
                ...HumanFields1
              }
            }
            query Bar {
              human(id: 4) {
                ...HumanFields2
              }
            }
            fragment HumanFields1 on Human {
              name
              ...HumanFields3
            }
            fragment HumanFields2 on Human {
              name
            }
            fragment HumanFields3 on Human {
              name
            }
            fragment Unused1 on Human {
              name
              ...Unused2
            }
            fragment Unused2 on Human {
              name
              ...Unused1
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 21, column: 1,
            message: "Fragment \"Unused1\" is never used."
        )

        try assertValidationError(
            error: errors[1], line: 25, column: 1,
            message: "Fragment \"Unused2\" is never used."
        )
    }

    @Test func containsUnknownAndUndefFragments() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            query Foo {
              human(id: 4) {
                ...bar
              }
            }
            fragment foo on Human {
              name
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 6, column: 1,
            message: "Fragment \"foo\" is never used."
        )
    }
}
