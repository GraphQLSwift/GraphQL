@testable import GraphQL
import XCTest

class UniqueVariableNamesRuleTests: ValidationTestCase {
    override func setUp() {
        rule = UniqueVariableNamesRule
    }

    func testUniqueVariableNames() throws {
        try assertValid(
            """
            query A($x: Int, $y: String) { __typename }
            query B($x: String, $y: Int) { __typename }
            """
        )
    }

    func testDuplicateVariableNames() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            query A($x: Int, $x: Int, $x: String) { __typename }
            query B($x: String, $x: Int) { __typename }
            query C($x: Int, $x: Int) { __typename }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 10),
                (line: 1, column: 19),
                (line: 1, column: 28),
            ],
            message: #"There can be only one variable named "$x"."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 2, column: 10),
                (line: 2, column: 22),
            ],
            message: #"There can be only one variable named "$x"."#
        )
        try assertValidationError(
            error: errors[2],
            locations: [
                (line: 3, column: 10),
                (line: 3, column: 19),
            ],
            message: #"There can be only one variable named "$x"."#
        )
    }
}
