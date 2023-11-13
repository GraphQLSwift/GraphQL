@testable import GraphQL
import XCTest

class FragmentsOnCompositeTypesRuleTests: ValidationTestCase {
    override func setUp() {
        rule = FragmentsOnCompositeTypesRule
    }

    func testObjectIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Dog {
              barks
            }
            """
        )
    }

    func testInterfaceIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on Pet {
              name
            }
            """
        )
    }

    func testObjectIsValidInlineFragmentType() throws {
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

    func testInterfaceIsValidInlineFragmentType() throws {
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

    func testInlineFragmentWithoutTypeIsValid() throws {
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

    func testUnionIsValidFragmentType() throws {
        try assertValid(
            """
            fragment validFragment on CatOrDog {
              __typename
            }
            """
        )
    }

    func testScalarIsInvalidFragmentType() throws {
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

    func testEnumIsInvalidFragmentType() throws {
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

    func testInputObjectIsInvalidFragmentType() throws {
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

    func testScalarIsInvalidInlineFragmentType() throws {
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
