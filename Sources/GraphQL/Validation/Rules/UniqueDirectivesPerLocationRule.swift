
/**
 * Unique directive names per location
 *
 * A GraphQL document is only valid if all non-repeatable directives at
 * a given location are uniquely named.
 *
 * See https://spec.graphql.org/draft/#sec-Directives-Are-Unique-Per-Location
 */
func UniqueDirectivesPerLocationRule(context: ValidationContext) -> Visitor {
    var uniqueDirectiveMap = [String: Bool]()

    let schema = context.schema
    let definedDirectives = schema.directives
    for directive in definedDirectives {
        uniqueDirectiveMap[directive.name] = !directive.isRepeatable
    }

    let astDefinitions = context.ast.definitions
    for def in astDefinitions {
        if let directive = def as? DirectiveDefinition {
            uniqueDirectiveMap[directive.name.value] = !directive.repeatable
        }
    }

    let schemaDirectives = [String: Directive]()
    var typeDirectivesMap = [String: [String: Directive]]()

    return Visitor(
        enter: { node, _, _, _, _ in
//            if let operation = node as? OperationDefinition {
            // Many different AST nodes may contain directives. Rather than listing
            // them all, just listen for entering any node, and check to see if it
            // defines any directives.
            if
                let directiveNodeResult = node.get(key: "directives"),
                case let .array(directiveNodes) = directiveNodeResult,
                let directives = directiveNodes as? [Directive]
            {
                var seenDirectives = [String: Directive]()
                if node.kind == .schemaDefinition || node.kind == .schemaExtensionDefinition {
                    seenDirectives = schemaDirectives
                } else if let node = node as? TypeDefinition {
                    let typeName = node.name.value
                    seenDirectives = typeDirectivesMap[typeName] ?? [:]
                    typeDirectivesMap[typeName] = seenDirectives
                } else if let node = node as? TypeExtensionDefinition {
                    let typeName = node.definition.name.value
                    seenDirectives = typeDirectivesMap[typeName] ?? [:]
                    typeDirectivesMap[typeName] = seenDirectives
                }

                for directive in directives {
                    let directiveName = directive.name.value

                    if uniqueDirectiveMap[directiveName] ?? false {
                        if let seenDirective = seenDirectives[directiveName] {
                            context.report(
                                error: GraphQLError(
                                    message: "The directive \"@\(directiveName)\" can only be used once at this location.",
                                    nodes: [seenDirective, directive]
                                )
                            )
                        } else {
                            seenDirectives[directiveName] = directive
                        }
                    }
                }
            }
            return .continue
        }
    )
}
