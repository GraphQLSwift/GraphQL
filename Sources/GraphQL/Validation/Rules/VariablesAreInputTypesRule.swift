/**
 * Variables are input types
 *
 * A GraphQL operation is only valid if all the variables it defines are of
 * input types (scalar, enum, or input object).
 *
 * See https://spec.graphql.org/draft/#sec-Variables-Are-Input-Types
 */
struct VariablesAreInputTypesRule: ValidationRule {
    let context: ValidationContext
    func enter(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition> {
        if context.inputType == nil {
            let error = GraphQLError(
                message: "Variable \"$\(variableDefinition.variable.name.value)\" cannot be non-input type \"\(variableDefinition.type.printed)\".",
                nodes: [variableDefinition.type]
            )
            context.report(error: error)
        }
        return .continue
    }
}
