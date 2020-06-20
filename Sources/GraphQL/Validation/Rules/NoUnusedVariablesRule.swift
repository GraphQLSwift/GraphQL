/**
 * No unused variables
 *
 * A GraphQL operation is only valid if all variables defined by an operation
 * are used, either directly or within a spread fragment.
 */
func NoUnusedVariablesRule(context: ValidationContext) -> Visitor {
    var variableDefs: [VariableDefinition] = []

    return Visitor(
        enter: { node, _, _, _, _ in
            if node is OperationDefinition {
                variableDefs = []
                return .continue
            }
            
            if let def = node as? VariableDefinition {
                variableDefs.append(def)
                return .continue
            }
            
            return .continue
        },
        leave: { node, _, _, _, _ -> VisitResult in
            guard let operation = node as? OperationDefinition else {
                return .continue
            }
            
            var variableNameUsed: [String: Bool] = [:]
            let usages = context.getRecursiveVariableUsages(operation: operation)
            
            for usage in usages {
                variableNameUsed[usage.node.name.value] = true
            }
            
            for variableDef in variableDefs {
                let variableName = variableDef.variable.name.value
                
                if variableNameUsed[variableName] != true {
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
