
/**
 * Lone anonymous operation
 *
 * A GraphQL document is only valid if when it contains an anonymous operation
 * (the query short-hand) that it contains only that one operation definition.
 *
 * See https://spec.graphql.org/draft/#sec-Lone-Anonymous-Operation
 */
func LoneAnonymousOperationRule(context: ValidationContext) -> Visitor {
    var operationCount = 0
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .document:
                let document = node as! Document
                operationCount = document.definitions.filter { $0 is OperationDefinition }.count
                return .continue
            case .operationDefinition:
                let operation = node as! OperationDefinition
                if operation.name == nil, operationCount > 1 {
                    context.report(
                        error: GraphQLError(
                            message: "This anonymous operation must be the only defined operation.",
                            nodes: [operation]
                        )
                    )
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
