
/**
 * Unique variable names
 *
 * A GraphQL operation is only valid if all its variables are uniquely named.
 */
func UniqueVariableNamesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let operation = node as? OperationDefinition {
                let variableDefinitions = operation.variableDefinitions

                let seenVariableDefinitions = Dictionary(grouping: variableDefinitions) { node in
                    node.variable.name.value
                }

                for (variableName, variableNodes) in seenVariableDefinitions {
                    if variableNodes.count > 1 {
                        context.report(
                            error: GraphQLError(
                                message: "There can be only one variable named \"$\(variableName)\".",
                                nodes: variableNodes.map { $0.variable.name }
                            )
                        )
                    }
                }
            }
            return .continue
        }
    )
}
