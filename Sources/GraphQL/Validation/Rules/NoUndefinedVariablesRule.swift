
/**
 * No undefined variables
 *
 * A GraphQL operation is only valid if all variables encountered, both directly
 * and via fragment spreads, are defined by that operation.
 *
 * See https://spec.graphql.org/draft/#sec-All-Variable-Uses-Defined
 */
func NoUndefinedVariablesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let operation = node as? OperationDefinition {
                let variableNameDefined = Set<String>(
                    operation.variableDefinitions.map { $0.variable.name.value }
                )

                let usages = context.getRecursiveVariableUsages(operation: operation)
                for usage in usages {
                    let node = usage.node
                    let varName = node.name.value
                    if !variableNameDefined.contains(varName) {
                        let message: String
                        if let operationName = operation.name {
                            message =
                                "Variable \"$\(varName)\" is not defined by operation \"\(operationName.value)\"."
                        } else {
                            message = "Variable \"$\(varName)\" is not defined."
                        }
                        context.report(
                            error: GraphQLError(
                                message: message,
                                nodes: [node, operation]
                            )
                        )
                    }
                }
            }
            return .continue
        }
    )
}
