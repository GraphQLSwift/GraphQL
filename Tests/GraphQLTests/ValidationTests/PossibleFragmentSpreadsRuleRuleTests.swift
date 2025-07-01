@testable import GraphQL
import Testing

class PossibleFragmentSpreadsRuleRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = PossibleFragmentSpreadsRule
    }

    @Test func testUsesAllVariables() throws {
        try assertValid(
            """
            query ($a: String, $b: String, $c: String) {
                field(a: $a, b: $b, c: $c)
            }
            """
        )
    }

    @Test func testOfTheSameObject() throws {
        try assertValid(
            """
            fragment objectWithinObject on Dog {
                ...dogFragment
            }
            fragment dogFragment on Dog {
                barkVolume
            }
            """
        )
    }

    @Test func testOfTheSameObjectWithInlineFragment() throws {
        try assertValid(
            """
            fragment objectWithinObjectAnon on Dog {
                ... on Dog {
                    barkVolume
                }
            }
            """
        )
    }

    @Test func testObjectIntoAnImplementedInterface() throws {
        try assertValid(
            """
            fragment objectWithinInterface on Pet {
                ...dogFragment
            }
            fragment dogFragment on Dog {
                barkVolume
            }
            """
        )
    }

    @Test func testObjectIntoContainingUnion() throws {
        try assertValid(
            """
            fragment objectWithinUnion on CatOrDog {
                ...dogFragment
            }
            fragment dogFragment on Dog {
                barkVolume
            }
            """
        )
    }

    @Test func testUnionIntoContainedObject() throws {
        try assertValid(
            """
            fragment unionWithinObject on Dog {
                ...catOrDogFragment
            }
            fragment catOrDogFragment on CatOrDog {
                __typename
            }
            """
        )
    }

    @Test func testUnionIntoOverlappingInterface() throws {
        try assertValid(
            """
            fragment unionWithinInterface on Pet {
                ...catOrDogFragment
            }
            fragment catOrDogFragment on CatOrDog {
                __typename
            }
            """
        )
    }

    @Test func testUnionIntoOverlappingUnion() throws {
        try assertValid(
            """
            fragment unionWithinUnion on DogOrHuman {
                ...catOrDogFragment
            }
            fragment catOrDogFragment on CatOrDog {
                __typename
            }
            """
        )
    }

    @Test func testInterfaceIntoImplementedObject() throws {
        try assertValid(
            """
            fragment interfaceWithinObject on Dog {
                ...petFragment
            }
            fragment petFragment on Pet {
                name
            }
            """
        )
    }

//    @Test func testInterfaceIntoOverlappingInterface() throws {
//        try assertValid(
//            """
//            fragment interfaceWithinInterface on Pet {
//                ...beingFragment
//            }
//            fragment beingFragment on Being {
//                name
//            }
//            """
//        )
//    }
//
//    @Test func testInterfaceIntoOverlappingInterfaceInInlineFragment() throws {
//        try assertValid(
//            """
//            fragment interfaceWithinInterface on Pet {
//                ... on Being {
//                    name
//                }
//            }
//            """
//        )
//    }

    @Test func testInterfaceIntoOverlappingUnion() throws {
        try assertValid(
            """
            fragment interfaceWithinUnion on CatOrDog {
                ...petFragment
            }
            fragment petFragment on Pet {
                name
            }
            """
        )
    }

    @Test func testIgnoresIncorrectTypeCaughtByFragmentsOnCompositeTypesRule() throws {
        try assertValid(
            """
            fragment petFragment on Pet {
                ...badInADifferentWay
            }
            fragment badInADifferentWay on String {
                name
            }
            """
        )
    }

    @Test func testIgnoresUnknownFragmentsCaughtByKnownFragmentNamesRule() throws {
        try assertValid(
            """
            fragment petFragment on Pet {
                ...UnknownFragment
            }
            """
        )
    }

    @Test func testDifferentObjectIntoObject() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidObjectWithinObject on Cat {
                ...dogFragment
            }
            fragment dogFragment on Dog {
                barkVolume
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "dogFragment" cannot be spread here as objects of type "Cat" can never be of type "Dog"."#
        )
    }

    @Test func testDifferentObjectIntoObjectInInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidObjectWithinObjectAnon on Cat {
              ... on Dog { barkVolume }
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 3,
            message: #"Fragment cannot be spread here as objects of type "Cat" can never be of type "Dog"."#
        )
    }

    @Test func testObjectIntoNotImplementingInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidObjectWithinInterface on Pet {
                ...humanFragment
            }
            fragment humanFragment on Human {
                pets {
                    name
                }
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "humanFragment" cannot be spread here as objects of type "Pet" can never be of type "Human"."#
        )
    }

    @Test func testObjectIntoNotContainingUnion() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidObjectWithinUnion on CatOrDog {
                ...humanFragment
            }
            fragment humanFragment on Human {
                pets {
                    name
                }
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "humanFragment" cannot be spread here as objects of type "CatOrDog" can never be of type "Human"."#
        )
    }

    @Test func testUnionIntoNotContainedObject() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidUnionWithinObject on Human {
                ...catOrDogFragment
            }
            fragment catOrDogFragment on CatOrDog {
                __typename
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "catOrDogFragment" cannot be spread here as objects of type "Human" can never be of type "CatOrDog"."#
        )
    }

    @Test func testUnionIntoNonOverlappingInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidUnionWithinInterface on Pet {
                ...humanOrAlienFragment
            }
            fragment humanOrAlienFragment on HumanOrAlien {
                __typename
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "humanOrAlienFragment" cannot be spread here as objects of type "Pet" can never be of type "HumanOrAlien"."#
        )
    }

    @Test func testUnionIntoNonOverlappingUnion() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidUnionWithinUnion on CatOrDog {
                ...humanOrAlienFragment
            }
            fragment humanOrAlienFragment on HumanOrAlien {
                __typename
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "humanOrAlienFragment" cannot be spread here as objects of type "CatOrDog" can never be of type "HumanOrAlien"."#
        )
    }

    @Test func testInterfaceIntoNonImplementingObject() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidInterfaceWithinObject on Cat {
                ...intelligentFragment
            }
            fragment intelligentFragment on Intelligent {
                iq
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "intelligentFragment" cannot be spread here as objects of type "Cat" can never be of type "Intelligent"."#
        )
    }

    @Test func testInterfaceIntNonOverlappingInterface() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidInterfaceWithinInterface on Pet {
                ...intelligentFragment
            }
            fragment intelligentFragment on Intelligent {
                iq
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "intelligentFragment" cannot be spread here as objects of type "Pet" can never be of type "Intelligent"."#
        )
    }

    @Test func testInterfaceIntoNonOverlappingInterfaceInInlineFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidInterfaceWithinInterfaceAnon on Pet {
                ...on Intelligent { iq }
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment cannot be spread here as objects of type "Pet" can never be of type "Intelligent"."#
        )
    }

    @Test func testInterfaceIntoNonOverlappingUnion() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            fragment invalidInterfaceWithinUnion on HumanOrAlien {
                ...petFragment
            }
            fragment petFragment on Pet {
                name
            }
            """
        )

        try assertValidationError(
            error: errors.first, line: 2, column: 5,
            message: #"Fragment "petFragment" cannot be spread here as objects of type "HumanOrAlien" can never be of type "Pet"."#
        )
    }
}
