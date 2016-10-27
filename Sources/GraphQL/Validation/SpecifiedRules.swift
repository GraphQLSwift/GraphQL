/**
 * This set includes all validation rules defined by the GraphQL spec.
 */
let specifiedRules: [(ValidationContext) -> Visitor] = [
//    UniqueOperationNames,
//    LoneAnonymousOperation,
//    KnownTypeNames,
//    FragmentsOnCompositeTypes,
//    VariablesAreInputTypes,
    ScalarLeafs,
    FieldsOnCorrectType,
//    UniqueFragmentNames,
//    KnownFragmentNames,
//    NoUnusedFragments,
//    PossibleFragmentSpreads,
//    NoFragmentCycles,
//    UniqueVariableNames,
//    NoUndefinedVariables,
//    NoUnusedVariables,
//    KnownDirectives,
//    KnownArgumentNames,
//    UniqueArgumentNames,
//    ArgumentsOfCorrectType,
//    ProvidedNonNullArguments,
//    DefaultValuesOfCorrectType,
//    VariablesInAllowedPosition,
//    OverlappingFieldsCanBeMerged,
//    UniqueInputFieldNames,
]
