
/**
 * Unique type names
 *
 * A GraphQL document is only valid if all defined types have unique names.
 */
func UniqueTypeNamesRule(context: SDLValidationContext) -> Visitor {
    var knownTypeNames = [String: Name]()
    let schema = context.getSchema()

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .scalarTypeDefinition:
                let definition = node as! ScalarTypeDefinition
                checkTypeName(node: definition)
                return .continue
            case .objectTypeDefinition:
                let definition = node as! ObjectTypeDefinition
                checkTypeName(node: definition)
                return .continue
            case .interfaceTypeDefinition:
                let definition = node as! InterfaceTypeDefinition
                checkTypeName(node: definition)
                return .continue
            case .unionTypeDefinition:
                let definition = node as! UnionTypeDefinition
                checkTypeName(node: definition)
                return .continue
            case .enumTypeDefinition:
                let definition = node as! EnumTypeDefinition
                checkTypeName(node: definition)
                return .continue
            case .inputObjectTypeDefinition:
                let definition = node as! InputObjectTypeDefinition
                checkTypeName(node: definition)
                return .continue
            default:
                return .continue
            }
        }
    )

    func checkTypeName(node: TypeDefinition) {
        let typeName = node.name.value

        if schema?.getType(name: typeName) != nil {
            context.report(
                error: GraphQLError(
                    message: "Type \"\(typeName)\" already exists in the schema. It cannot also be defined in this type definition.",
                    nodes: [node.name]
                )
            )
            return
        }

        if let knownNameNode = knownTypeNames[typeName] {
            context.report(
                error: GraphQLError(
                    message: "There can be only one type named \"\(typeName)\".",
                    nodes: [knownNameNode, node.name]
                )
            )
        } else {
            knownTypeNames[typeName] = node.name
        }
    }
}
