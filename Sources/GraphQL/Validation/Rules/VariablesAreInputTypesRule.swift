
/**
 * Variables are input types
 *
 * A GraphQL operation is only valid if all the variables it defines are of
 * input types (scalar, enum, or input object).
 *
 * See https://spec.graphql.org/draft/#sec-Variables-Are-Input-Types
 */
func VariablesAreInputTypesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let variableDefinition = node as? VariableDefinition {
                let variableType = variableDefinition.type
                if let type = typeFromAST(schema: context.schema, inputTypeAST: variableType) {
                    guard !isInputType(type: type) else {
                        return .continue
                    }

                    let variableName = variableDefinition.variable.name.value
                    let typeName = print(ast: variableType)
                    context.report(
                        error: GraphQLError(
                            message: "Variable \"$\(variableName)\" cannot be non-input type \"\(typeName)\".",
                            nodes: [variableType]
                        )
                    )
                }
            }
            return .continue
        }
    )
}
