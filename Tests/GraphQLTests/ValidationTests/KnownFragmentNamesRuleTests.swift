@testable import GraphQL
import XCTest

class KnownFragmentNamesRuleTests : ValidationTestCase {
    override func setUp() {
        rule = KnownFragmentNamesRule.self
    }
    
    func testValidWithKnownFragmentName() throws {
        try assertValid("""
            fragment f on Dog { name }
            query { dog { ...f } }
        """)
    }
    
    func testInvalidWithUnknownFragmentName() throws {
        try assertInvalid(
            errorCount: 1,
            query: "{ dog { ...f } }"
        )
    }
}
