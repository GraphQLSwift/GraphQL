@testable import GraphQL
import Testing

class ProvidedRequiredArgumentsRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = ProvidedRequiredArgumentsRule
    }

    @Test func ignoresUnknownArguments() throws {
        try assertValid(
            """
            {
              dog {
                isHouseTrained(unknownArgument: true)
              }
            }
            """
        )
    }

    // MARK: Valid non-nullable value

    @Test func argOnOptionalArg() throws {
        try assertValid(
            """
            {
              dog {
                isHouseTrained(atOtherHomes: true)
              }
            }
            """
        )
    }

    @Test func noArgOnOptionalArg() throws {
        try assertValid(
            """
            {
              dog {
                isHouseTrained
              }
            }
            """
        )
    }

    @Test func noArgOnNonNullFieldWithDefault() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                nonNullFieldWithDefault
              }
            }
            """
        )
    }

    @Test func multipleArgs() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleReqs(req1: 1, req2: 2)
              }
            }
            """
        )
    }

    @Test func multipleArgsInReverseOrder() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleReqs(req2: 2, req1: 1)
              }
            }
            """
        )
    }

    @Test func noArgsOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts
              }
            }
            """
        )
    }

    @Test func oneArgOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts(opt1: 1)
              }
            }
            """
        )
    }

    @Test func secondArgOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts(opt2: 1)
              }
            }
            """
        )
    }

    @Test func multipleRequiredArgsOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4)
              }
            }
            """
        )
    }

    @Test func multipleRequiredAndOneOptionalArgOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4, opt1: 5)
              }
            }
            """
        )
    }

    @Test func allRequiredAndOptionalArgsOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
              }
            }
            """
        )
    }

    // MARK: Invalid non-nullable value

    @Test func missingOneNonNullableArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              complicatedArgs {
                multipleReqs(req2: 2)
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 3, column: 5),
            ],
            message: #"Field "multipleReqs" argument "req1" of type "Int!" is required, but it was not provided."#
        )
    }

    @Test func missingMultipleNonNullableArguments() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            {
              complicatedArgs {
                multipleReqs
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 3, column: 5),
            ],
            message: #"Field "multipleReqs" argument "req1" of type "Int!" is required, but it was not provided."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 3, column: 5),
            ],
            message: #"Field "multipleReqs" argument "req2" of type "Int!" is required, but it was not provided."#
        )
    }

    @Test func incorrectValueAndMissingArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              complicatedArgs {
                multipleReqs(req1: "one")
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 3, column: 5),
            ],
            message: #"Field "multipleReqs" argument "req2" of type "Int!" is required, but it was not provided."#
        )
    }

    // MARK: Directive arguments

    @Test func ignoresUnknonwnDirectives() throws {
        try assertValid(
            """
            {
              dog @unknown
            }
            """
        )
    }

    @Test func withDirectivesOfValidTypes() throws {
        try assertValid(
            """
            {
              dog @include(if: true) {
                name
              }
              human @skip(if: false) {
                name
              }
            }
            """
        )
    }

    @Test func withDirectiveWithMissingTypes() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            {
              dog @include {
                name @skip
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 2, column: 7),
            ],
            message: #"Directive "@include" argument "if" of type "Boolean!" is required, but it was not provided."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [
                (line: 3, column: 10),
            ],
            message: #"Directive "@skip" argument "if" of type "Boolean!" is required, but it was not provided."#
        )
    }

    // TODO: Add SDL tests
}
