func noSubselectionAllowedMessage(fieldName: String, type: GraphQLType) -> String {
    return "Field \"\(fieldName)\" must not have a selection since " +
           "type \"\(type)\" has no subfields."
}

func requiredSubselectionMessage(fieldName: String, type: GraphQLType) -> String {
    return "Field \"\(fieldName)\" of type \"\(type)\" must have a " +
           "selection of subfields. Did you mean \"\(fieldName) { ... }\"?"
}

/**
 * Scalar leafs
 *
 * A GraphQL document is valid only if all leaf fields (fields without
 * sub selections) are of scalar or enum types.
 */
func ScalarLeafs(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, key, parent, path, ancestors in
            if let node = node as? Field {
                if let type = context.type {
                    if isLeafType(type: type) {
                        if let selectionSet = node.selectionSet {
                            let error = GraphQLError(
                                message: noSubselectionAllowedMessage(fieldName: node.name.value, type: type),
                                nodes: [selectionSet]
                            )
                            context.report(error: error)
                        }
                    } else if node.selectionSet == nil {
                        let error = GraphQLError(
                            message: requiredSubselectionMessage(fieldName: node.name.value, type: type),
                            nodes: [node]
                        )
                        context.report(error: error)
                    }
                }
            }

            return .continue
        }
    )
}
