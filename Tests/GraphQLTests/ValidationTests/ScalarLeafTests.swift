@testable import GraphQL
import XCTest

class ScalarLeafTests : ValidationTestCase {

    override func setUp() {
        rule = ScalarLeafs
    }

    func testValidWhenScalarSelection() throws {
        try assertValid(
            "fragment scalarSelection on Dog { barks }"
        )
    }

    func testInvalidWhenObjectTypeMissingSelection() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "query objectTypeMissingSelection { human }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 36,
            message: requiredSubselectionMessage(fieldName: "human", type: ValidationExampleHuman)
        )
    }

    func testInvalidWhenInterfaceTypeMissingSelection() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "query interfaceTypeMissingSelection { human { pets } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 47,
            message: requiredSubselectionMessage(fieldName: "pets", type: GraphQLList(ValidationExamplePet))
        )
    }

    func testValidWhenScalarSelectionWithArgs() throws {
        try assertValid(
            "fragment scalarSelectionWithArgs on Dog { doesKnowCommand(dogCommand: SIT) }"
        )
    }

    func testInvalidWhenScalarSelectionsNotAllowedOnBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment scalarSelectionsNotAllowedOnBoolean on Dog { barks { sinceWhen } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 61,
            message: noSubselectionAllowedMessage(fieldName: "barks", type: GraphQLBoolean)
        )
    }

    func testInvalidWhenScalarSelectionsNotAllowedOnEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment scalarSelectionsNotAllowedOnEnum on Cat { furColor { inHexdec } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 61,
            message: noSubselectionAllowedMessage(fieldName: "furColor", type: ValidationExampleFurColor)
        )
    }

    func testInvalidWhenScalarSelectionsNotAllowedWithArgs() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment scalarSelectionsNotAllowedWithArgs on Dog { doesKnowCommand(dogCommand: SIT) { sinceWhen } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 87,
            message: noSubselectionAllowedMessage(fieldName: "doesKnowCommand", type: GraphQLBoolean)
        )
    }

    func testInvalidWhenScalarSelectionsNotAllowedWithDirectives() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment scalarSelectionsNotAllowedWithDirectives on Dog { name @include(if: true) { isAlsoHumanName } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 84,
            message: noSubselectionAllowedMessage(fieldName: "name", type: GraphQLString)
        )
    }

    func testInvalidWhenScalarSelectionsNotAllowedWithDirectivesAndArgs() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment scalarSelectionsNotAllowedWithDirectivesAndArgs on Dog { doesKnowCommand(dogCommand: SIT) @include(if: true) { sinceWhen } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 119,
            message: noSubselectionAllowedMessage(fieldName: "doesKnowCommand", type: GraphQLBoolean)
        )
    }

}

extension ScalarLeafTests {
    static var allTests: [(String, (ScalarLeafTests) -> () throws -> Void)] {
        return [
            ("testValidWhenScalarSelection", testValidWhenScalarSelection),
            ("testInvalidWhenObjectTypeMissingSelection", testInvalidWhenObjectTypeMissingSelection),
            ("testInvalidWhenInterfaceTypeMissingSelection", testInvalidWhenInterfaceTypeMissingSelection),
            ("testValidWhenScalarSelectionWithArgs", testValidWhenScalarSelectionWithArgs),
            ("testInvalidWhenScalarSelectionsNotAllowedOnBoolean", testInvalidWhenScalarSelectionsNotAllowedOnBoolean),
            ("testInvalidWhenScalarSelectionsNotAllowedOnEnum", testInvalidWhenScalarSelectionsNotAllowedOnEnum),
            ("testInvalidWhenScalarSelectionsNotAllowedWithArgs", testInvalidWhenScalarSelectionsNotAllowedWithArgs),
            ("testInvalidWhenScalarSelectionsNotAllowedWithDirectives", testInvalidWhenScalarSelectionsNotAllowedWithDirectives),
            ("testInvalidWhenScalarSelectionsNotAllowedWithDirectivesAndArgs", testInvalidWhenScalarSelectionsNotAllowedWithDirectivesAndArgs),
        ]
    }
}

