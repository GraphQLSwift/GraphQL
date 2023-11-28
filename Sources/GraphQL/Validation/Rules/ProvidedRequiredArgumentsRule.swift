import Foundation

/**
 * Provided required arguments
 *
 * A field or directive is only valid if all required (non-null without a
 * default value) field arguments have been provided.
 */
func ProvidedRequiredArgumentsRule(context: ValidationContext) -> Visitor {
    var requiredArgsMap = [String: [String: String]]()

    let schema = context.schema
    let definedDirectives = schema.directives
    for directive in definedDirectives {
        var requiredArgMap = [String: String]()
        directive.args.filter { arg in
            isRequiredArgument(arg)
        }.forEach { arg in
            requiredArgMap[arg.name] = "\(arg.type)"
        }
        requiredArgsMap[directive.name] = requiredArgMap
    }

    let astDefinitions = context.ast.definitions
    for def in astDefinitions {
        if let directive = def as? DirectiveDefinition {
            var requiredArgMap = [String: String]()
            directive.arguments.filter { arg in
                isRequiredArgumentNode(arg)
            }.forEach { arg in
                requiredArgMap[arg.name.value] = "\(arg.type)"
            }

            requiredArgsMap[directive.name.value] = requiredArgMap
        }
    }

    return Visitor(
        leave: { node, _, _, _, _ in
            if let fieldNode = node as? Field {
                guard let fieldDef = context.fieldDef else {
                    return .continue
                }

                let providedArguments = Set(fieldNode.arguments.map { $0.name.value })

                for argDef in fieldDef.args {
                    if !providedArguments.contains(argDef.name), isRequiredArgument(argDef) {
                        context.report(error: GraphQLError(
                            message: "Field \"\(fieldDef.name)\" argument \"\(argDef.name)\" of type \"\(argDef.type)\" is required, but it was not provided.",
                            nodes: [fieldNode]
                        ))
                    }
                }
            }

            if let directiveNode = node as? Directive {
                let directiveName = directiveNode.name.value

                if let requiredArgs = requiredArgsMap[directiveName] {
                    let argNodes = directiveNode.arguments
                    let argNodeMap = Set(argNodes.map { $0.name.value })
                    for (argName, argType) in requiredArgs {
                        if !argNodeMap.contains(argName) {
                            context.report(error: GraphQLError(
                                message: "Directive \"@\(directiveName)\" argument \"\(argName)\" of type \"\(argType)\" is required, but it was not provided.",
                                nodes: [directiveNode]
                            ))
                        }
                    }
                }
            }
            return .continue
        }
    )
}

func isRequiredArgumentNode(_ arg: InputValueDefinition) -> Bool {
    return arg.type.kind == .nonNullType && arg.defaultValue == nil
}
