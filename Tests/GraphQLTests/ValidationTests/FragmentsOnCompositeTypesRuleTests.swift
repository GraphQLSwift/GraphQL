@testable import GraphQL
import Testing

class FragmentsOnCompositeTypesRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = FragmentsOnCompositeTypesRule
    }

    @Test func testObjectIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Dog {
              barks
            }
            """
        )
    }

    @Test func testInterfaceIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Pet {
              name
            }
            """
        )
    }

    @Test func testObjectIsValidInlineFragmentType() throws {
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

    @Test func testInterfaceIsValidInlineFragmentType() throws {
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

    @Test func testInlineFragmentWithoutTypeIsValid() throws {
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

    @Test func testUnionIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on CatOrDog {
              __typename
            }
            """
        )
    }

    @Test func testScalarIsInvalidFragmentType() throws {
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

    @Test func testEnumIsInvalidFragmentType() throws {
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

    @Test func testInputObjectIsInvalidFragmentType() throws {
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

    @Test func testScalarIsInvalidInlineFragmentType() throws {
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
