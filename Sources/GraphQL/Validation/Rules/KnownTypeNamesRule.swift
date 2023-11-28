
/**
 * Known type names
 *
 * A GraphQL document is only valid if referenced types (specifically
 * variable definitions and fragment conditions) are defined by the type schema.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-Spread-Type-Existence
 */
func KnownTypeNamesRule(context: ValidationContext) -> Visitor {
    let definitions = context.ast.definitions
    let existingTypesMap = context.schema.typeMap

    var typeNames = Set<String>()
    for typeName in existingTypesMap.keys {
        typeNames.insert(typeName)
    }
    for definition in definitions {
        if
            let type = definition as? TypeDefinition,
            let nameResult = type.get(key: "name"),
            case let .node(nameNode) = nameResult,
            let name = nameNode as? Name
        {
            typeNames.insert(name.value)
        }
    }

    return Visitor(
        enter: { node, _, _, _, _ in
            if let type = node as? NamedType {
                let typeName = type.name.value
                if !typeNames.contains(typeName) {
                    // TODO: Add SDL support

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
