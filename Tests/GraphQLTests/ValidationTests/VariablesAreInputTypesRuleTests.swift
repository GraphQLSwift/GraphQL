@testable import GraphQL
import XCTest

class VariablesAreInputTypesRuleTests : ValidationTestCase {
    override func setUp() {
        rule = VariablesAreInputTypesRule.self
    }
    
    func testValidWithInputObject() throws {
        try assertValid(
            "query ($treat: Treat) { dog { __typename } } "
        )
    }

    func testInvalidWithObject() throws {
        try assertInvalid(errorCount: 1, query:
            "query ($dog: Dog) { dog { __typename } } "
        )
    }
}
