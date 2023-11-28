
/**
 * Unique operation names
 *
 * A GraphQL document is only valid if all defined operations have unique names.
 *
 * See https://spec.graphql.org/draft/#sec-Operation-Name-Uniqueness
 */
func UniqueOperationNamesRule(context: ValidationContext) -> Visitor {
    var knownOperationNames = [String: Name]()
    return Visitor(
        enter: { node, _, _, _, _ in
            if let operation = node as? OperationDefinition {
                if let operationName = operation.name {
                    if let knownOperationName = knownOperationNames[operationName.value] {
                        context.report(
                            error: GraphQLError(
                                message: "There can be only one operation named \"\(operationName.value)\".",
                                nodes: [knownOperationName, operationName]
                            )
                        )
                    } else {
                        knownOperationNames[operationName.value] = operationName
                    }
                }
            }
            return .continue
        }
    )
}
