/**
 * This set includes all validation rules defined by the GraphQL spec.
 */
let specifiedRules: [ValidationRule.Type] = [
    //    UniqueOperationNames,
    //    LoneAnonymousOperation,
    //    KnownTypeNames,
    //    FragmentsOnCompositeTypes,
    //    VariablesAreInputTypes,
    ScalarLeafsRule.self,
    FieldsOnCorrectTypeRule.self,
    //    UniqueFragmentNames,
    //    KnownFragmentNames,
    //    NoUnusedFragments,
    PossibleFragmentSpreadsRule.self,
    //    NoFragmentCycles,
    //    UniqueVariableNames,
    //    NoUndefinedVariables,
    NoUnusedVariablesRule.self,
    //    KnownDirectives,
    KnownArgumentNamesRule.self,
    //    UniqueArgumentNames,
    //    ArgumentsOfCorrectType,
    ProvidedNonNullArgumentsRule.self,
    //    DefaultValuesOfCorrectType,
    //    VariablesInAllowedPosition,
    //    OverlappingFieldsCanBeMerged,
    //    UniqueInputFieldNames,
    VariablesAreInputTypesRule.self
]
