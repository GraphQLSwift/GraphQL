/**
 * No unused variables
 *
 * A GraphQL operation is only valid if all variables defined by an operation
 * are used, either directly or within a spread fragment.
 */
class NoUnusedVariablesRule: ValidationRule {
    private var variableDefs: [VariableDefinition] = []
    let context: ValidationContext
    required init(context: ValidationContext) { self.context = context }
    
    func enter(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition> {
        variableDefs = []
        return .continue
    }
    
    func enter(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition> {
        variableDefs.append(variableDefinition)
        return .continue
    }
    
    func leave(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition> {
        let usages = Set(context.getRecursiveVariableUsages(operation: operationDefinition).map { $0.node.name })
        
        for variableDef in variableDefs where !usages.contains(variableDef.variable.name) {
            let variableName = variableDef.variable.name.value
            
            context.report(
                error: GraphQLError(
                    message: operationDefinition.name.map {
                        "Variable \"$\(variableName)\" is never used in operation \"\($0.value)\"."
                    } ?? "Variable \"$\(variableName)\" is never used.",
                    nodes: [variableDef]
                )
            )
        }
        
        return .continue
    }
}
