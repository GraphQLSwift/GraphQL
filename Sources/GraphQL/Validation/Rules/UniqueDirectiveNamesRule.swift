
/**
 * Unique directive names
 *
 * A GraphQL document is only valid if all defined directives have unique names.
 */
func UniqueDirectiveNamesRule(
    context: SDLValidationContext
) -> Visitor {
    var knownDirectiveNames = [String: Name]()
    let schema = context.getSchema()

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .directiveDefinition:
                let node = node as! DirectiveDefinition
                let directiveName = node.name.value
                if schema?.getDirective(name: directiveName) != nil {
                    context.report(
                        error: GraphQLError(
                            message: "Directive \"@\(directiveName)\" already exists in the schema. It cannot be redefined.",
                            nodes: [node.name]
                        )
                    )
                    return .continue
                }
                if let knownName = knownDirectiveNames[directiveName] {
                    context.report(
                        error: GraphQLError(
                            message: "There can be only one directive named \"@\(directiveName)\".",
                            nodes: [knownName, node.name]
                        )
                    )
                } else {
                    knownDirectiveNames[directiveName] = node.name
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
