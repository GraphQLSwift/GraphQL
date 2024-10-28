
/**
 * Known type names
 *
 * A GraphQL document is only valid if referenced types (specifically
 * variable definitions and fragment conditions) are defined by the type schema.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-Spread-Type-Existence
 */
func KnownTypeNamesRule(context: SDLorNormalValidationContext) -> Visitor {
    let definitions = context.ast.definitions
    let existingTypesMap = context.getSchema()?.typeMap ?? [:]

    var typeNames = Set<String>()
    for typeName in existingTypesMap.keys {
        typeNames.insert(typeName)
    }
    for definition in definitions {
        if
            isTypeSystemDefinitionNode(definition),
            let nameResult = definition.get(key: "name"),
            case let .node(nameNode) = nameResult,
            let name = nameNode as? Name
        {
            typeNames.insert(name.value)
        }
    }

    return Visitor(
        enter: { node, _, parent, _, ancestors in
            if let type = node as? NamedType {
                let typeName = type.name.value
                if !typeNames.contains(typeName) {
                    let definitionNode = ancestors.count > 2 ? ancestors[2] : parent
                    var isSDL = false
                    if let definitionNode = definitionNode, case let .node(node) = definitionNode {
                        isSDL = isSDLNode(node)
                    }
                    if isSDL, standardTypeNames.contains(typeName) {
                        return .continue
                    }

                    let suggestedTypes = suggestionList(
                        input: typeName,
                        options: Array(typeNames)
                    )
                    context.report(
                        error: GraphQLError(
                            message: "Unknown type \"\(typeName)\"." +
                                didYouMean(suggestions: suggestedTypes),
                            nodes: [node]
                        )
                    )
                }
            }
            return .continue
        }
    )
}

let standardTypeNames: Set<String> = {
    var result = specifiedScalarTypes.map { $0.name }
    result.append(contentsOf: introspectionTypes.map { $0.name })
    return Set(result)
}()

func isSDLNode(_ value: Node) -> Bool {
    return isTypeSystemDefinitionNode(value) || isTypeSystemExtensionNode(value)
}
