@testable import GraphQL
import Testing

class FieldsOnCorrectTypeTests: ValidationTestCase {
    override init() {
        super.init()
        rule = FieldsOnCorrectTypeRule
    }

    @Test func validWithObjectFieldSelection() throws {
        try assertValid(
            "fragment objectFieldSelection on Dog { __typename name }"
        )
    }

    @Test func validWithAliasedObjectFieldSelection() throws {
        try assertValid(
            "fragment aliasedObjectFieldSelection on Dog { tn : __typename otherName : name }"
        )
    }

    @Test func validWithInterfaceFieldSelection() throws {
        try assertValid(
            "fragment interfaceFieldSelection on Pet { __typename name }"
        )
    }

    @Test func validWithAliasedInterfaceFieldSelection() throws {
        try assertValid(
            "fragment aliasedInterfaceFieldSelection on Pet { otherName : name }"
        )
    }

    @Test func validWithLyingAliasSelection() throws {
        try assertValid(
            "fragment lyingAliasSelection on Dog { name : nickname }"
        )
    }

    @Test func validWithInlineFragment() throws {
        try assertValid(
            "fragment inlineFragment on Pet { ... on Dog { name } ... { name } }"
        )
    }

    @Test func validWhenMetaFieldSelectionOnUnion() throws {
        try assertValid(
            "fragment metaFieldSelectionOnUnion on CatOrDog { __typename }"
        )
    }

    @Test func validWithIgnoresFieldsOnUnknownType() throws {
        try assertValid(
            "fragment ignoresFieldsOnUnknownType on UnknownType { unknownField }"
        )
    }

    @Test func invalidWhenTypeKnownAgain() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            fragment typeKnownAgain on Pet {
                unknown_pet_field {
                    ... on Cat {
                        unknown_cat_field
                    }
                }
            }
            """
        )

        try assertValidationError(
            error: errors[0], line: 2, column: 5,
            message: "Cannot query field \"unknown_pet_field\" on type \"Pet\"."
        )

        try assertValidationError(
            error: errors[1], line: 4, column: 13,
            message: "Cannot query field \"unknown_cat_field\" on type \"Cat\"."
        )
    }

    @Test func invalidWhenFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment fieldNotDefined on Dog { meowVolume }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 35,
            message: "Cannot query field \"meowVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    @Test func invalidWhenDeepFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment deepFieldNotDefined on Dog { unknown_field { deeper_unknown_field }}"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 39,
            message: "Cannot query field \"unknown_field\" on type \"Dog\"."
        )
    }

    @Test func invalidWhenSubFieldNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment subFieldNotDefined on Human { pets { unknown_field } }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 47,
            message: "Cannot query field \"unknown_field\" on type \"Pet\"."
        )
    }

    @Test func invalidWhenFieldNotDefinedOnInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment fieldNotDefinedOnInlineFragment on Pet { ... on Dog { meowVolume } }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 64,
            message: "Cannot query field \"meowVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    @Test func invalidWhenAliasedFieldTargetNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment aliasedFieldTargetNotDefined on Dog { volume : mooVolume }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 48,
            message: "Cannot query field \"mooVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    @Test func invalidWhenAliasedLyingFieldTargetNotDefined() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment aliasedLyingFieldTargetNotDefined on Dog { barkVolume : kawVolume }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 53,
            message: "Cannot query field \"kawVolume\" on type \"Dog\". Did you mean \"barkVolume\"?"
        )
    }

    @Test func invalidWhenNotDefinedOnInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment notDefinedOnInterface on Pet { tailLength }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 41,
            message: "Cannot query field \"tailLength\" on type \"Pet\"."
        )
    }

    @Test func invalidWhenDefinedOnImplementorsButNotInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: "fragment definedOnImplementorsButNotInterface on Pet { nickname }"
        )

        try assertValidationError(
            error: errors.first, line: 1, column: 56,
            message: "Cannot query field \"nickname\" on type \"Pet\". Did you mean \"name\"?"
        )
    }

//    @Test func invalidWhenDirectFieldSelectionOnUnion() throws {
//        let errors = try assertInvalid(
//            errorCount: 1,
//            query: """
//            fragment directFieldSelectionOnUnion on CatOrDog {
//                directField
//            }
//            """
//        )
//
//        try assertValidationError(
//            error: errors.first, line: 1, column: 0,
//            message: ""
//        )
//    }
//
//    @Test func invalidWhenDefinedOnImplementorsQueriedOnUnion() throws {
//        let errors = try assertInvalid(
//            errorCount: 1,
//            query: """
//            fragment definedOnImplementorsQueriedOnUnion on CatOrDog {
//                name
//            }
//            """
//        )
//
//        try assertValidationError(
//            error: errors.first, line: 1, column: 0,
//            message: ""
//        )
//    }
}
