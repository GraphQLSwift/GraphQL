
/**
 * Unique argument definition names
 *
 * A GraphQL Object or Interface type is only valid if all its fields have uniquely named arguments.
 * A GraphQL Directive is only valid if all its arguments are uniquely named.
 */
func UniqueArgumentDefinitionNamesRule(
    context: SDLValidationContext
) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let directiveNode = node as? DirectiveDefinition {
                let argumentNodes = directiveNode.arguments
                checkArgUniqueness(
                    parentName: "@\(directiveNode.name.value)",
                    argumentNodes: argumentNodes
                )
            } else if let node = node as? InterfaceTypeDefinition {
                checkArgUniquenessPerField(name: node.name, fields: node.fields)
            } else if let node = node as? InterfaceExtensionDefinition {
                checkArgUniquenessPerField(
                    name: node.definition.name,
                    fields: node.definition.fields
                )
            } else if let node = node as? ObjectTypeDefinition {
                checkArgUniquenessPerField(name: node.name, fields: node.fields)
            } else if let node = node as? TypeExtensionDefinition {
                checkArgUniquenessPerField(
                    name: node.definition.name,
                    fields: node.definition.fields
                )
            }
            return .continue
        }
    )

    func checkArgUniquenessPerField(
        name: Name,
        fields: [FieldDefinition]
    ) {
        let typeName = name.value
        let fieldNodes = fields
        for fieldDef in fieldNodes {
            let fieldName = fieldDef.name.value

            let argumentNodes = fieldDef.arguments

            checkArgUniqueness(parentName: "\(typeName).\(fieldName)", argumentNodes: argumentNodes)
        }
    }

    func checkArgUniqueness(
        parentName: String,
        argumentNodes: [InputValueDefinition]
    ) {
        let seenArgs = [String: [InputValueDefinition]](grouping: argumentNodes) { arg in
            arg.name.value
        }
        for (argName, argNodes) in seenArgs {
            if argNodes.count > 1 {
                context.report(
                    error: GraphQLError(
                        message: "Argument \"\(parentName)(\(argName):)\" can only be defined once.",
                        nodes: argNodes.map { node in node.name }
                    )
                )
            }
        }
    }
}
