
func ProvidedRequiredArgumentsOnDirectivesRule(
    context: SDLorNormalValidationContext
) -> Visitor {
    var requiredArgsMap = [String: [String: String]]()

    let schema = context.getSchema()
    let definedDirectives = schema?.directives ?? specifiedDirectives
    for directive in definedDirectives {
        var requiredArgs = [String: String]()
        for arg in directive.args.filter({ isRequiredArgument($0) }) {
            requiredArgs[arg.name] = arg.type.debugDescription
        }
        requiredArgsMap[directive.name] = requiredArgs
    }

    let astDefinitions = context.ast.definitions
    for def in astDefinitions {
        if let def = def as? DirectiveDefinition {
            let argNodes = def.arguments
            var requiredArgs = [String: String]()
            for arg in argNodes.filter({ isRequiredArgumentNode($0) }) {
                requiredArgs[arg.name.value] = print(ast: arg.type)
            }
            requiredArgsMap[def.name.value] = requiredArgs
        }
    }

    return Visitor(
        // Validate on leave to allow for deeper errors to appear first.
        leave: { node, _, _, _, _ in
            switch node.kind {
            case .directive:
                let directiveNode = node as! Directive
                let directiveName = directiveNode.name.value
                if let requiredArgs = requiredArgsMap[directiveName] {
                    let argNodes = directiveNode.arguments
                    let argNodeMap = Set(argNodes.map(\.name.value))
                    for (argName, argType) in requiredArgs {
                        if !argNodeMap.contains(argName) {
                            context.report(
                                error: GraphQLError(
                                    message: "Argument \"@\(directiveName)(\(argName):)\" of type \"\(argType)\" is required, but it was not provided.",
                                    nodes: [directiveNode]
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

func isRequiredArgumentNode(
    arg: InputValueDefinition
) -> Bool {
    return arg.type.kind == .nonNullType && arg.defaultValue == nil
}

func isRequiredArgumentNode(
    arg: VariableDefinition
) -> Bool {
    return arg.type.kind == .nonNullType && arg.defaultValue == nil
}
