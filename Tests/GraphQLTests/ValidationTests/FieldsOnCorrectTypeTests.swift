@testable import GraphQL
import XCTest

class FieldsOnCorrectTypeTests : ValidationTestCase {

    override func setUp() {
        rule = FieldsOnCorrectType
    }

    func testValidWithObjectFieldSelection() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    func testValidWithAliasedObjectFieldSelection() throws {
        try assertValid(
            "fragment aliasedObjectFieldSelection on Dog { tn : __typename otherName : name }"
        )
    }

    func testValidWithInterfaceFieldSelection() throws {
        try assertValid(
            "fragment interfaceFieldSelection on Pet { __typename name }"
        )
    }

    func testValidWithAliasedInterfaceFieldSelection() throws {
        try assertValid(
            "fragment aliasedInterfaceFieldSelection on Pet { otherName : name }"
        )
    }

    func testValidWithLyingAliasSelection() throws {
        try assertValid(
            "fragment lyingAliasSelection on Dog { name : nickname }"
        )
    }

    func testValidWithInlineFragment() throws {
        try assertValid(
            "fragment inlineFragment on Pet { ... on Dog { name } ... { name } }"
        )
    }

    func testValidWhenMetaFieldSelectionOnUnion() throws {
        try assertValid(
            "fragment metaFieldSelectionOnUnion on CatOrDog { __typename }"
        )
    }

    func testValidWithIgnoresFieldsOnUnknownType() throws {
        try assertValid(
            "fragment ignoresFieldsOnUnknownType on UnknownType { unknownField }"
        )
    }

    func testInvalidWhenTypeKnownAgain() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment typeKnownAgain on Pet { unknown_pet_field { ... on Cat { unknown_cat_field } } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 34,
            message: "Cannot query field \"unknown_pet_field\" on type \"Pet\"."
        )
    }

    func testInvalidWhenFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment fieldNotDefined on Dog { meowVolume }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 35,
            message: "Cannot query field \"meowVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    func testInvalidWhenDeepFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment deepFieldNotDefined on Dog { unknown_field { deeper_unknown_field }}"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 39,
            message: "Cannot query field \"unknown_field\" on type \"Dog\"."
        )
    }

    func testInvalidWhenSubFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment subFieldNotDefined on Human { pets { unknown_field } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 47,
            message: "Cannot query field \"unknown_field\" on type \"Pet\"."
        )
    }

    func testInvalidWhenFieldNotDefinedOnInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment fieldNotDefinedOnInlineFragment on Pet { ... on Dog { meowVolume } }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 64,
            message: "Cannot query field \"meowVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    func testInvalidWhenAliasedFieldTargetNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment aliasedFieldTargetNotDefined on Dog { volume : mooVolume }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 48,
            message: "Cannot query field \"mooVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    func testInvalidWhenAliasedLyingFieldTargetNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment aliasedLyingFieldTargetNotDefined on Dog { barkVolume : kawVolume }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 53,
            message: "Cannot query field \"kawVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    func testInvalidWhenNotDefinedOnInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment notDefinedOnInterface on Pet { tailLength }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 41,
            message: "Cannot query field \"tailLength\" on type \"Pet\"."
        )
    }

    func testInvalidWhenDefinedOnImplementorsButNotInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment definedOnImplementorsButNotInterface on Pet { nickname }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 56,
            message: "Cannot query field \"nickname\" on type \"Pet\". Did you mean \"name\"?"
        )
    }

    /*
    func testInvalidWhenDirectFieldSelectionOnUnion() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment directFieldSelectionOnUnion on CatOrDog { directField }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 0,
            message: ""
        )
    }

    func testInvalidWhenDefinedOnImplementorsQueriedOnUnion() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment definedOnImplementorsQueriedOnUnion on CatOrDog { name }"
        )
        try assertValidationError(
            error: errors.first, line: 1, column: 0,
            message: ""
        )
    }
    */

}

extension FieldsOnCorrectTypeTests {
    static var allTests: [(String, (FieldsOnCorrectTypeTests) -> () throws -> Void)] {
        return [
            ("testValidWithObjectFieldSelection", testValidWithObjectFieldSelection),
            ("testValidWithAliasedObjectFieldSelection", testValidWithAliasedObjectFieldSelection),
            ("testValidWithInterfaceFieldSelection", testValidWithInterfaceFieldSelection),
            ("testValidWithAliasedInterfaceFieldSelection", testValidWithAliasedInterfaceFieldSelection),
            ("testValidWithLyingAliasSelection", testValidWithLyingAliasSelection),
            ("testValidWithInlineFragment", testValidWithInlineFragment),
            ("testValidWhenMetaFieldSelectionOnUnion", testValidWhenMetaFieldSelectionOnUnion),
            ("testValidWithIgnoresFieldsOnUnknownType", testValidWithIgnoresFieldsOnUnknownType),
            ("testInvalidWhenTypeKnownAgain", testInvalidWhenTypeKnownAgain),
            ("testInvalidWhenFieldNotDefined", testInvalidWhenFieldNotDefined),
            ("testInvalidWhenDeepFieldNotDefined", testInvalidWhenDeepFieldNotDefined),
            ("testInvalidWhenSubFieldNotDefined", testInvalidWhenSubFieldNotDefined),
            ("testInvalidWhenFieldNotDefinedOnInlineFragment", testInvalidWhenFieldNotDefinedOnInlineFragment),
            ("testInvalidWhenAliasedFieldTargetNotDefined", testInvalidWhenAliasedFieldTargetNotDefined),
            ("testInvalidWhenAliasedLyingFieldTargetNotDefined", testInvalidWhenAliasedLyingFieldTargetNotDefined),
            ("testInvalidWhenNotDefinedOnInterface", testInvalidWhenNotDefinedOnInterface),
            ("testInvalidWhenDefinedOnImplementorsButNotInterface", testInvalidWhenDefinedOnImplementorsButNotInterface),
            /*
            ("testInvalidWhenDirectFieldSelectionOnUnion", testInvalidWhenDirectFieldSelectionOnUnion),
            ("testInvalidWhenDefinedOnImplementorsQueriedOnUnion", testInvalidWhenDefinedOnImplementorsQueriedOnUnion),
             */
        ]
    }
}
