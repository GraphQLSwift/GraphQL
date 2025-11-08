@testable import GraphQL
import Testing

class VariablesInAllowedPositionRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = VariablesInAllowedPositionRule
    }

    @Test func booleanToBoolean() throws {
        try assertValid(
            """
            query Query($booleanArg: Boolean)
            {
              complicatedArgs {
                booleanArgField(booleanArg: $booleanArg)
              }
            }
            """
        )
    }

    @Test func booleanToBooleanWithinFragment() throws {
        try assertValid(
            """
            fragment booleanArgFrag on ComplicatedArgs {
              booleanArgField(booleanArg: $booleanArg)
            }
            query Query($booleanArg: Boolean)
            {
              complicatedArgs {
                ...booleanArgFrag
              }
            }
            """
        )

        try assertValid(
            """
            query Query($booleanArg: Boolean)
            {
              complicatedArgs {
                ...booleanArgFrag
              }
            }
            fragment booleanArgFrag on ComplicatedArgs {
              booleanArgField(booleanArg: $booleanArg)
            }
            """
        )
    }

    @Test func nonNullBooleanToBoolean() throws {
        try assertValid(
            """
            query Query($nonNullBooleanArg: Boolean!)
            {
              complicatedArgs {
                booleanArgField(booleanArg: $nonNullBooleanArg)
              }
            }
            """
        )
    }

    @Test func nonNullBooleanToBooleanWithinFragment() throws {
        try assertValid(
            """
            fragment booleanArgFrag on ComplicatedArgs {
              booleanArgField(booleanArg: $nonNullBooleanArg)
            }

            query Query($nonNullBooleanArg: Boolean!)
            {
              complicatedArgs {
                ...booleanArgFrag
              }
            }
            """
        )
    }

    @Test func stringListToStringList() throws {
        try assertValid(
            """
            query Query($stringListVar: [String])
            {
              complicatedArgs {
                stringListArgField(stringListArg: $stringListVar)
              }
            }
            """
        )
    }

    @Test func nonNullStringListToStringList() throws {
        try assertValid(
            """
            query Query($stringListVar: [String!])
            {
              complicatedArgs {
                stringListArgField(stringListArg: $stringListVar)
              }
            }
            """
        )
    }

    @Test func stringToStringListInItemPosition() throws {
        try assertValid(
            """
            query Query($stringVar: String)
            {
              complicatedArgs {
                stringListArgField(stringListArg: [$stringVar])
              }
            }
            """
        )
    }

    @Test func nonNullStringToStringListInItemPosition() throws {
        try assertValid(
            """
            query Query($stringVar: String!)
            {
              complicatedArgs {
                stringListArgField(stringListArg: [$stringVar])
              }
            }
            """
        )
    }

    @Test func complexInputToComplexInput() throws {
        try assertValid(
            """
            query Query($complexVar: ComplexInput)
            {
              complicatedArgs {
                complexArgField(complexArg: $complexVar)
              }
            }
            """
        )
    }

    @Test func complexInputToComplexInputInFieldPosition() throws {
        try assertValid(
            """
            query Query($boolVar: Boolean = false)
            {
              complicatedArgs {
                complexArgField(complexArg: {requiredArg: $boolVar})
              }
            }
            """
        )
    }

    @Test func nonNullBooleanToNonNullBooleanInDirective() throws {
        try assertValid(
            """
            query Query($boolVar: Boolean!)
            {
              dog @include(if: $boolVar)
            }
            """
        )
    }

    @Test func intToIntNonNull() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($intArg: Int) {
              complicatedArgs {
                nonNullIntArgField(nonNullIntArg: $intArg)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 3, column: 39),
            ],
            message: #"Variable "$intArg" of type "Int" used in position expecting type "Int!"."#
        )
    }

    @Test func intToIntNonNullWithinFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment nonNullIntArgFieldFrag on ComplicatedArgs {
              nonNullIntArgField(nonNullIntArg: $intArg)
            }

            query Query($intArg: Int) {
              complicatedArgs {
                ...nonNullIntArgFieldFrag
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 5, column: 13),
                (line: 2, column: 37),
            ],
            message: #"Variable "$intArg" of type "Int" used in position expecting type "Int!"."#
        )
    }

    @Test func intToIntNonNullWithinNestedFragment() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            fragment outerFrag on ComplicatedArgs {
              ...nonNullIntArgFieldFrag
            }

            fragment nonNullIntArgFieldFrag on ComplicatedArgs {
              nonNullIntArgField(nonNullIntArg: $intArg)
            }

            query Query($intArg: Int) {
              complicatedArgs {
                ...outerFrag
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 9, column: 13),
                (line: 6, column: 37),
            ],
            message: #"Variable "$intArg" of type "Int" used in position expecting type "Int!"."#
        )
    }

    @Test func stringToBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($stringVar: String) {
              complicatedArgs {
                booleanArgField(booleanArg: $stringVar)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 3, column: 33),
            ],
            message: #"Variable "$stringVar" of type "String" used in position expecting type "Boolean"."#
        )
    }

    @Test func stringToStringList() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($stringVar: String) {
              complicatedArgs {
                stringListArgField(stringListArg: $stringVar)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 3, column: 39),
            ],
            message: #"Variable "$stringVar" of type "String" used in position expecting type "[String]"."#
        )
    }

    @Test func booleanToNonNullBooleanInDirective() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($boolVar: Boolean) {
              dog @include(if: $boolVar)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 2, column: 20),
            ],
            message: #"Variable "$boolVar" of type "Boolean" used in position expecting type "Boolean!"."#
        )
    }

    @Test func stringToNonNullBooleanInDirective() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($stringVar: String) {
              dog @include(if: $stringVar)
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 2, column: 20),
            ],
            message: #"Variable "$stringVar" of type "String" used in position expecting type "Boolean!"."#
        )
    }

    @Test func stringListToStringListNonNull() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($stringListVar: [String]) {
              complicatedArgs {
                stringListNonNullArgField(stringListNonNullArg: $stringListVar)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 3, column: 53),
            ],
            message: #"Variable "$stringListVar" of type "[String]" used in position expecting type "[String!]"."#
        )
    }

    @Test func optionalVariableWithDefaultValue() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query Query($intVar: Int = null) {
              complicatedArgs {
                nonNullIntArgField(nonNullIntArg: $intVar)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [
                (line: 1, column: 13),
                (line: 3, column: 39),
            ],
            message: #"Variable "$intVar" of type "Int" used in position expecting type "Int!"."#
        )
    }

    @Test func intOptionalWithNonNullDefaultValue() throws {
        try assertValid("""
        query Query($intVar: Int = 1) {
          complicatedArgs {
            nonNullIntArgField(nonNullIntArg: $intVar)
          }
        }
        """)
    }

    @Test func optionalVariableWithDefaultValueAndNonNullField() throws {
        try assertValid("""
        query Query($intVar: Int) {
          complicatedArgs {
            nonNullFieldWithDefault(nonNullIntArg: $intVar)
          }
        }
        """)
    }

    @Test func booleanWithDefaultValueInDirective() throws {
        try assertValid("""
        query Query($boolVar: Boolean = false) {
          dog @include(if: $boolVar)
        }
        """)
    }
}
