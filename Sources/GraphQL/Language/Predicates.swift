
func isTypeSystemDefinitionNode(
    _ node: Node
) -> Bool {
    return
        node.kind == Kind.schemaDefinition ||
        isTypeDefinitionNode(node) ||
        node.kind == Kind.directiveDefinition
}

func isTypeDefinitionNode(
    _ node: Node
) -> Bool {
    return
        node.kind == Kind.scalarTypeDefinition ||
        node.kind == Kind.objectTypeDefinition ||
        node.kind == Kind.interfaceTypeDefinition ||
        node.kind == Kind.unionTypeDefinition ||
        node.kind == Kind.enumTypeDefinition ||
        node.kind == Kind.inputObjectTypeDefinition
}

func isTypeSystemExtensionNode(
    _ node: Node
) -> Bool {
    return
        node.kind == Kind.schemaExtensionDefinition ||
        isTypeExtensionNode(node)
}

func isTypeExtensionNode(
    _ node: Node
) -> Bool {
    return
        node.kind == Kind.scalarExtensionDefinition ||
        node.kind == Kind.typeExtensionDefinition ||
        node.kind == Kind.interfaceExtensionDefinition ||
        node.kind == Kind.unionExtensionDefinition ||
        node.kind == Kind.enumExtensionDefinition ||
        node.kind == Kind.inputObjectExtensionDefinition
}
