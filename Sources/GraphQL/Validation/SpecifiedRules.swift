/**
 * This set includes all validation rules defined by the GraphQL spec.
 */
let specifiedRules: [(ValidationContext) -> Visitor] = [
//    UniqueOperationNames,
//    LoneAnonymousOperation,
//    KnownTypeNames,
//    FragmentsOnCompositeTypes,
//    VariablesAreInputTypes,
    ScalarLeafsRule,
    FieldsOnCorrectTypeRule,
//    UniqueFragmentNames,
//    KnownFragmentNames,
//    NoUnusedFragments,
    PossibleFragmentSpreadsRule,
//    NoFragmentCycles,
//    UniqueVariableNames,
//    NoUndefinedVariables,
//    NoUnusedVariablesRule,
//    KnownDirectives,
    KnownArgumentNamesRule,
//    UniqueArgumentNames,
//    ArgumentsOfCorrectType,
    ProvidedNonNullArgumentsRule,
//    DefaultValuesOfCorrectType,
//    VariablesInAllowedPosition,
//    OverlappingFieldsCanBeMerged,
//    UniqueInputFieldNames,
]
