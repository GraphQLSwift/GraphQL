@testable import GraphQL
import XCTest

class KnownArgumentNamesTests: ValidationTestCase {
    override func setUp() {
        rule = KnownArgumentNamesRule
    }

    func testValidWithObjectWithoutArguments() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    func testValidWithCorrectArgumentNames() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename isHousetrained(atOtherHomes: true) }"
        )
    }

    func testInvalidWithSlightlyMisspelledArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment objectFieldSelection on Dog { __typename isHousetrained(atOtherHomees: true) }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 66,
            message: #"Field "isHousetrained" on type "Dog" does not have argument "atOtherHomees". Did you mean "atOtherHomes"?"#
        )
    }

    func testInvalidWithUnrelatedArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment objectFieldSelection on Dog { __typename name(uppercased: true) }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 56,
            message: #"Field "name" on type "Dog" does not have argument "uppercased"."#
        )
    }
}
