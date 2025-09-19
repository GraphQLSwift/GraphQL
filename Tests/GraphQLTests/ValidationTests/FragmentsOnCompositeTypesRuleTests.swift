@testable import GraphQL
import Testing

class FragmentsOnCompositeTypesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = FragmentsOnCompositeTypesRule
    }

    @Test func objectIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Dog {
              barks
            }
            """
        )
    }

    @Test func interfaceIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Pet {
              name
            }
            """
        )
    }

    @Test func objectIsValidInlineFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Pet {
              ... on Dog {
                barks
              }
            }
            """
        )
    }

    @Test func interfaceIsValidInlineFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Mammal {
              ... on Canine {
                name
              }
            }
            """
        )
    }

    @Test func inlineFragmentWithoutTypeIsValid() throws {
        try assertValid(
            """
            fragment validFragment on Pet {
              ... {
                name
              }
            }
            """
        )
    }

    @Test func unionIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on CatOrDog {
              __typename
            }
            """
        )
    }

    @Test func scalarIsInvalidFragmentType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment scalarFragment on Boolean {
              bad
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 28)],
            message: "Fragment \"scalarFragment\" cannot condition on non composite type \"Boolean\"."
        )
    }

    @Test func enumIsInvalidFragmentType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment scalarFragment on FurColor {
              bad
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 28)],
            message: "Fragment \"scalarFragment\" cannot condition on non composite type \"FurColor\"."
        )
    }

    @Test func inputObjectIsInvalidFragmentType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment inputFragment on ComplexInput {
              stringField
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 27)],
            message: "Fragment \"inputFragment\" cannot condition on non composite type \"ComplexInput\"."
        )
    }

    @Test func scalarIsInvalidInlineFragmentType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment invalidFragment on Pet {
              ... on String {
                barks
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 10)],
            message: "Fragment cannot condition on non composite type \"String\"."
        )
    }
}
