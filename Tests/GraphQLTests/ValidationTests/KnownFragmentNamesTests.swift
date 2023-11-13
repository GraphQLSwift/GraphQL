@testable import GraphQL
import XCTest

class KnownFragmentNamesTests: ValidationTestCase {
    override func setUp() {
        rule = KnownFragmentNamesRule
    }

    func testKnownFragmentNamesAreValid() throws {
        try assertValid(
            """
            {
              human(id: 4) {
                ...HumanFields1
                ... on Human {
                  ...HumanFields2
                }
                ... {
                  name
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

    func testUnknownFragmentNamesAreInvalid() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            {
              human(id: 4) {
                ...UnknownFragment1
                ... on Human {
                  ...UnknownFragment2
                }
              }
            }
            fragment HumanFields on Human {
              name
              ...UnknownFragment3
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 8)],
            message: "Unknown fragment \"UnknownFragment1\"."
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 5, column: 10)],
            message: "Unknown fragment \"UnknownFragment2\"."
        )
        try assertValidationError(
            error: errors[2],
            locations: [(line: 11, column: 6)],
            message: "Unknown fragment \"UnknownFragment3\"."
        )
    }
}
