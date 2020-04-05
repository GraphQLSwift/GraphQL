@testable import GraphQL
import XCTest

class ProvidedNonNullArgumentsTests : ValidationTestCase {

    override func setUp() {
        rule = ProvidedNonNullArguments
    }

    func testValidWithObjectWithoutArguments() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    func testValidWithCorrectArgumentNames() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename doesKnowCommand(dogCommand: SIT) }"
        )
    }

    func testInvalidWithSlightlyMisspelledArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment objectFieldSelection on Dog { __typename doesKnowCommand(command: SIT) }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 51,
            message: #"Field "doesKnowCommand" on type "Dog" is missing required arguments "dogCommand"."#
        )
    }

    func testInvalidWithMissingRequiredArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment objectFieldSelection on Dog { __typename doesKnowCommand }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 51,
            message: #"Field "doesKnowCommand" on type "Dog" is missing required arguments "dogCommand"."#
        )
    }

}

extension ProvidedNonNullArgumentsTests {
    static var allTests: [(String, (ProvidedNonNullArgumentsTests) -> () throws -> Void)] {
        return [
            ("testValidWithObjectWithoutArguments", testValidWithObjectWithoutArguments),
            ("testValidWithCorrectArgumentNames", testValidWithCorrectArgumentNames),
            ("testInvalidWithSlightlyMisspelledArgument", testInvalidWithSlightlyMisspelledArgument),
            ("testInvalidWithMissingRequiredArgument", testInvalidWithMissingRequiredArgument),
        ]
    }
}
