
/**
 * Executable definitions
 *
 * A GraphQL document is only valid for execution if all definitions are either
 * operation or fragment definitions.
 *
 * See https://spec.graphql.org/draft/#sec-Executable-Definitions
 */
func ExecutableDefinitionsRule(context: ValidationContext) -> Visitor {
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
            if let node = node as? Document {
                for definition in node.definitions {
                    if !isExecutable(definition) {
                        var defName = "schema"
                        if let definition = definition as? TypeDefinition {
                            defName = "\"\(definition.name.value)\""
                        } else if let definition = definition as? TypeExtensionDefinition {
                            defName = "\"\(definition.definition.name.value)\""
                        }
                        context.report(
                            error: GraphQLError(
                                message: "The \(defName) definition is not executable.",
                                nodes: [definition]
                            )
                        )
                    }
                }
            }
            return .continue
        }
    )
}

func isExecutable(_ definition: Definition) -> Bool {
    definition.kind == .operationDefinition || definition
        .kind == .fragmentDefinition
}
