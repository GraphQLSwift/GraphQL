/**
 * This set includes all validation rules defined by the GraphQL spec.
 */
public let specifiedRules: [(ValidationContext) -> Visitor] = [
    ExecutableDefinitionsRule,
    UniqueOperationNamesRule,
    LoneAnonymousOperationRule,
//    SingleFieldSubscriptionsRule,
    KnownTypeNamesRule,
    FragmentsOnCompositeTypesRule,
    VariablesAreInputTypesRule,
    ScalarLeafsRule,
    FieldsOnCorrectTypeRule,
    UniqueFragmentNamesRule,
    KnownFragmentNamesRule,
    NoUnusedFragmentsRule,
    PossibleFragmentSpreadsRule,
    NoFragmentCyclesRule,
    UniqueVariableNamesRule,
    NoUndefinedVariablesRule,
    NoUnusedVariablesRule,
    KnownDirectivesRule,
    UniqueDirectivesPerLocationRule,
//    DeferStreamDirectiveOnRootFieldRule,
//    DeferStreamDirectiveOnValidOperationsRule,
//    DeferStreamDirectiveLabelRule,
    KnownArgumentNamesRule,
    UniqueArgumentNamesRule,
    ValuesOfCorrectTypeRule,
    ProvidedRequiredArgumentsRule,
    VariablesInAllowedPositionRule,
//    OverlappingFieldsCanBeMergedRule,
    UniqueInputFieldNamesRule,
]

/**
 * @internal
 */
public let specifiedSDLRules: [SDLValidationRule] = [
    LoneSchemaDefinitionRule,
    UniqueOperationTypesRule,
    UniqueTypeNamesRule,
    UniqueEnumValueNamesRule,
    UniqueFieldDefinitionNamesRule,
    UniqueArgumentDefinitionNamesRule,
    UniqueDirectiveNamesRule,
    KnownTypeNamesRule,
    KnownDirectivesRule,
    UniqueDirectivesPerLocationRule,
    PossibleTypeExtensionsRule,
//    KnownArgumentNamesOnDirectivesRule,
    UniqueArgumentNamesRule,
    UniqueInputFieldNamesRule,
//    ProvidedRequiredArgumentsOnDirectivesRule,
]
