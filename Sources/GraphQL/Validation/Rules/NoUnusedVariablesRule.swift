/**
 * No unused variables
 *
 * A GraphQL operation is only valid if all variables defined by an operation
 * are used, either directly or within a spread fragment.
 */
func NoUnusedVariablesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { _, _, _, _, _ in
            .continue
        },
        leave: { node, _, _, _, _ -> VisitResult in
            guard let operation = node as? OperationDefinition else {
                return .continue
            }

            let usages = context.getRecursiveVariableUsages(operation: operation)
            let variableNameUsed = Set(usages.map { usage in
                usage.node.name.value
            })

            for variableDef in operation.variableDefinitions {
                let variableName = variableDef.variable.name.value
                if !variableNameUsed.contains(variableName) {
                    context.report(
                        error: GraphQLError(
                            message: operation.name.map {
                                "Variable \"$\(variableName)\" is never used in operation \"\($0.value)\"."
                            } ?? "Variable \"$\(variableName)\" is never used.",
                            nodes: [variableDef]
                        )
                    )
                }
            }
            return .continue
        }
    )
}
