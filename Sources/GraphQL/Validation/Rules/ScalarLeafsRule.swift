func noSubselectionAllowedMessage(fieldName: String, type: any GraphQLType) -> String {
    return "Field \"\(fieldName)\" must not have a selection since " +
           "type \"\(type)\" has no subfields."
}

func requiredSubselectionMessage(fieldName: String, type: any GraphQLType) -> String {
    return "Field \"\(fieldName)\" of type \"\(type)\" must have a " +
           "selection of subfields. Did you mean \"\(fieldName) { ... }\"?"
}

/**
 * Scalar leafs
 *
 * A GraphQL document is valid only if all leaf fields (fields without
 * sub selections) are of scalar or enum types.
 */
struct ScalarLeafsRule: ValidationRule {
    let context: ValidationContext
    func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
        if let type = context.type {
            if isLeafType(type: getNamedType(type: type)) {
                if let selectionSet = field.selectionSet {
                    let error = GraphQLError(
                        message: noSubselectionAllowedMessage(fieldName: field.name.value, type: type),
                        nodes: [selectionSet]
                    )
                    context.report(error: error)
                }
            } else if field.selectionSet == nil {
                let error = GraphQLError(
                    message: requiredSubselectionMessage(fieldName: field.name.value, type: type),
                    nodes: [field]
                )
                context.report(error: error)
            }
        }
        return .continue
    }
}
