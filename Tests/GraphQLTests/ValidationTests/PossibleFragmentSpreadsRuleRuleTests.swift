@testable import GraphQL
import Testing

class PossibleFragmentSpreadsRuleRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = PossibleFragmentSpreadsRule
    }

    @Test func usesAllVariables() throws {
        try assertValid(
            """
            query ($a: String, $b: String, $c: String) {
                field(a: $a, b: $b, c: $c)
            }
            """
        )
    }

    @Test func ofTheSameObject() throws {
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

    @Test func ofTheSameObjectWithInlineFragment() throws {
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

    @Test func objectIntoAnImplementedInterface() throws {
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

    @Test func objectIntoContainingUnion() throws {
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

    @Test func unionIntoContainedObject() throws {
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

    @Test func unionIntoOverlappingInterface() throws {
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

    @Test func unionIntoOverlappingUnion() throws {
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

    @Test func interfaceIntoImplementedObject() throws {
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

//    @Test func interfaceIntoOverlappingInterface() throws {
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
//    @Test func interfaceIntoOverlappingInterfaceInInlineFragment() throws {
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

    @Test func interfaceIntoOverlappingUnion() throws {
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

    @Test func ignoresIncorrectTypeCaughtByFragmentsOnCompositeTypesRule() throws {
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

    @Test func ignoresUnknownFragmentsCaughtByKnownFragmentNamesRule() throws {
        try assertValid(
            """
            fragment petFragment on Pet {
                ...UnknownFragment
            }
            """
        )
    }

    @Test func differentObjectIntoObject() throws {
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

    @Test func differentObjectIntoObjectInInlineFragment() throws {
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

    @Test func objectIntoNotImplementingInterface() throws {
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

    @Test func objectIntoNotContainingUnion() throws {
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

    @Test func unionIntoNotContainedObject() throws {
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

    @Test func unionIntoNonOverlappingInterface() throws {
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

    @Test func unionIntoNonOverlappingUnion() throws {
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

    @Test func interfaceIntoNonImplementingObject() throws {
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

    @Test func interfaceIntNonOverlappingInterface() throws {
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

    @Test func interfaceIntoNonOverlappingInterfaceInInlineFragment() throws {
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

    @Test func interfaceIntoNonOverlappingUnion() throws {
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
