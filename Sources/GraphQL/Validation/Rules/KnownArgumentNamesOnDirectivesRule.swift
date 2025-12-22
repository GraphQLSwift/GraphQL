func KnownArgumentNamesOnDirectivesRule(
    context: SDLorNormalValidationContext
) -> Visitor {
    var directiveArgs = [String: [String]]()

    let schema = context.getSchema()
    let definedDirectives = schema?.directives ?? specifiedDirectives
    for directive in definedDirectives {
        directiveArgs[directive.name] = directive.args.map(\.name)
    }

    let astDefinitions = context.ast.definitions
    for def in astDefinitions {
        if def.kind == .directiveDefinition {
            let def = def as! DirectiveDefinition
            let argsNodes = def.arguments
            directiveArgs[def.name.value] = argsNodes.map(\.name.value)
        }
    }

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .directive:
                let directiveNode = node as! Directive
                let directiveName = directiveNode.name.value
                let knownArgs = directiveArgs[directiveName]

                if let knownArgs = knownArgs {
                    for argNode in directiveNode.arguments {
                        let argName = argNode.name.value
                        if !knownArgs.contains(argName) {
                            let suggestions = suggestionList(input: argName, options: knownArgs)
                            context.report(
                                error: GraphQLError(
                                    message: "Unknown argument \"\(argName)\" on directive \"@\(directiveName)\"." +
                                        didYouMean(suggestions: suggestions),
                                    nodes: [argNode]
                                )
                            )
                        }
                    }
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
