/**
 * This set includes all validation rules defined by the GraphQL spec.
 */
let specifiedRules: [(ValidationContext) -> Visitor] = [
//    uniqueOperationNames,
//    loneAnonymousOperation,
//    knownTypeNames,
//    fragmentsOnCompositeTypes,
//    variablesAreInputTypes,
    ScalarLeafs,
    FieldsOnCorrectType,
//    uniqueFragmentNames,
//    knownFragmentNames,
//    noUnusedFragments,
//    possibleFragmentSpreads,
//    noFragmentCycles,
//    uniqueVariableNames,
//    noUndefinedVariables,
//    noUnusedVariables,
//    knownDirectives,
//    knownArgumentNames,
//    uniqueArgumentNames,
//    argumentsOfCorrectType,
//    providedNonNullArguments,
//    defaultValuesOfCorrectType,
//    variablesInAllowedPosition,
//    overlappingFieldsCanBeMerged,
//    uniqueInputFieldNames,
]
