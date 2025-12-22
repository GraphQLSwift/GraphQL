
/**
 * Unique argument names
 *
 * A GraphQL field or directive is only valid if all supplied arguments are
 * uniquely named.
 *
 * See https://spec.graphql.org/draft/#sec-Argument-Names
 */
func UniqueArgumentNamesRule(context: ASTValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .field:
                let field = node as! Field
                let argumentNodes = field.arguments
                let seenArgs = Dictionary(grouping: argumentNodes) { $0.name.value }

                for (argName, argNodes) in seenArgs {
                    if argNodes.count > 1 {
                        context.report(
                            error: GraphQLError(
                                message: "There can be only one argument named \"\(argName)\".",
                                nodes: argNodes.map { $0.name }
                            )
                        )
                    }
                }
                return .continue
            case .directive:
                let directive = node as! Directive
                let argumentNodes = directive.arguments
                let seenArgs = Dictionary(grouping: argumentNodes) { $0.name.value }

                for (argName, argNodes) in seenArgs {
                    if argNodes.count > 1 {
                        context.report(
                            error: GraphQLError(
                                message: "There can be only one argument named \"\(argName)\".",
                                nodes: argNodes.map { $0.name }
                            )
                        )
                    }
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
