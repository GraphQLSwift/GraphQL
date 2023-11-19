@testable import GraphQL
import XCTest

class ProvidedRequiredArgumentsRuleTests: ValidationTestCase {
    override func setUp() {
        rule = ProvidedRequiredArgumentsRule
    }

    func testIgnoresUnknownArguments() throws {
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

    func testArgOnOptionalArg() throws {
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

    func testNoArgOnOptionalArg() throws {
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

    func testNoArgOnNonNullFieldWithDefault() throws {
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

    func testMultipleArgs() throws {
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

    func testMultipleArgsInReverseOrder() throws {
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

    func testNoArgsOnMultipleOptional() throws {
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

    func testOneArgOnMultipleOptional() throws {
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

    func testSecondArgOnMultipleOptional() throws {
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

    func testMultipleRequiredArgsOnMixedList() throws {
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

    func testMultipleRequiredAndOneOptionalArgOnMixedList() throws {
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

    func testAllRequiredAndOptionalArgsOnMixedList() throws {
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

    func testMissingOneNonNullableArgument() throws {
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

    func testMissingMultipleNonNullableArguments() throws {
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

    func testIncorrectValueAndMissingArgument() throws {
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

    func testIgnoresUnknonwnDirectives() throws {
        try assertValid(
            """
            {
              dog @unknown
            }
            """
        )
    }

    func testWithDirectivesOfValidTypes() throws {
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

    func testWithDirectiveWithMissingTypes() throws {
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
