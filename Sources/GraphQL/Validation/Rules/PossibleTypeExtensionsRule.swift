
/**
 * Possible type extension
 *
 * A type extension is only valid if the type is defined and has the same kind.
 */
func PossibleTypeExtensionsRule(
    context: SDLValidationContext
) -> Visitor {
    let schema = context.getSchema()
    var definedTypes = [String: TypeDefinition]()

    for def in context.getDocument().definitions {
        if let def = def as? TypeDefinition {
            definedTypes[def.name.value] = def
        }
    }

    return Visitor(
        enter: { node, _, _, _, _ in
            if let node = node as? ScalarExtensionDefinition {
                checkExtension(node: node)
            } else if let node = node as? TypeExtensionDefinition {
                checkExtension(node: node)
            } else if let node = node as? InterfaceExtensionDefinition {
                checkExtension(node: node)
            } else if let node = node as? UnionExtensionDefinition {
                checkExtension(node: node)
            } else if let node = node as? EnumExtensionDefinition {
                checkExtension(node: node)
            } else if let node = node as? InputObjectExtensionDefinition {
                checkExtension(node: node)
            }
            return .continue
        }
    )

    func checkExtension(node: TypeExtension) {
        let typeName = node.name.value
        let defNode = definedTypes[typeName]
        let existingType = schema?.getType(name: typeName)

        var expectedKind: Kind? = nil
        if let defNode = defNode {
            expectedKind = defKindToExtKind[defNode.kind]
        } else if let existingType = existingType {
            expectedKind = typeToExtKind(type: existingType)
        }

        if let expectedKind = expectedKind {
            if expectedKind != node.kind {
                let kindStr = extensionKindToTypeName(kind: node.kind)
                var nodes: [any Node] = []
                if let defNode = defNode {
                    nodes.append(defNode)
                }
                nodes.append(node)
                context.report(
                    error: GraphQLError(
                        message: "Cannot extend non-\(kindStr) type \"\(typeName)\".",
                        nodes: nodes
                    )
                )
            }
        } else {
            var allTypeNames = Array(definedTypes.keys)
            allTypeNames.append(contentsOf: schema?.typeMap.keys ?? [])

            context.report(
                error: GraphQLError(
                    message: "Cannot extend type \"\(typeName)\" because it is not defined." +
                        didYouMean(suggestions: suggestionList(
                            input: typeName,
                            options: allTypeNames
                        )),
                    nodes: [node.name]
                )
            )
        }
    }
}

let defKindToExtKind: [Kind: Kind] = [
    .scalarTypeDefinition: .scalarExtensionDefinition,
    .objectTypeDefinition: .typeExtensionDefinition,
    .interfaceTypeDefinition: .interfaceExtensionDefinition,
    .unionTypeDefinition: .unionExtensionDefinition,
    .enumTypeDefinition: .enumExtensionDefinition,
    .inputObjectTypeDefinition: .inputObjectExtensionDefinition,
]

func typeToExtKind(type: GraphQLNamedType) -> Kind {
    if type is GraphQLScalarType {
        return .scalarExtensionDefinition
    }
    if type is GraphQLObjectType {
        return .typeExtensionDefinition
    }
    if type is GraphQLInterfaceType {
        return .interfaceExtensionDefinition
    }
    if type is GraphQLUnionType {
        return .unionExtensionDefinition
    }
    if type is GraphQLEnumType {
        return .enumExtensionDefinition
    }
    if type is GraphQLInputObjectType {
        return .inputObjectExtensionDefinition
    }
    // Not reachable. All possible types have been considered
    fatalError("Unexpected type: \(type)")
}

func extensionKindToTypeName(kind: Kind) -> String {
    switch kind {
    case .scalarExtensionDefinition:
        return "scalar"
    case .typeExtensionDefinition:
        return "object"
    case .interfaceExtensionDefinition:
        return "interface"
    case .unionExtensionDefinition:
        return "union"
    case .enumExtensionDefinition:
        return "enum"
    case .inputObjectExtensionDefinition:
        return "input object"
    // Not reachable. All possible types have been considered
    default:
        fatalError("Unexpected kind: \(kind)")
    }
}
