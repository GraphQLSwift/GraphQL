@testable import GraphQL
import Testing

class KnownArgumentNamesTests: ValidationTestCase {
    override init() {
        super.init()
        rule = KnownArgumentNamesRule
    }

    @Test func validWithObjectWithoutArguments() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    @Test func validWithCorrectArgumentNames() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename isHousetrained(atOtherHomes: true) }"
        )
    }

    @Test func invalidWithSlightlyMisspelledArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment objectFieldSelection on Dog { __typename isHousetrained(atOtherHomees: true) }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 66,
            message: #"Field "isHousetrained" on type "Dog" does not have argument "atOtherHomees". Did you mean "atOtherHomes"?"#
        )
    }

    @Test func invalidWithUnrelatedArgument() throws {
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
