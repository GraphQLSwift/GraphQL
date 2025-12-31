
/**
 * Unique input field names
 *
 * A GraphQL input object value is only valid if all supplied fields are
 * uniquely named.
 *
 * See https://spec.graphql.org/draft/#sec-Input-Object-Field-Uniqueness
 */
func UniqueInputFieldNamesRule(context: ASTValidationContext) -> Visitor {
    var knownNameStack = [[String: Name]]()
    var knownNames = [String: Name]()

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .objectValue:
                knownNameStack.append(knownNames)
                knownNames = [:]
                return .continue
            case .objectField:
                let objectField = node as! ObjectField
                let fieldName = objectField.name.value
                if let knownName = knownNames[fieldName] {
                    context.report(
                        error: GraphQLError(
                            message: "There can be only one input field named \"\(fieldName)\".",
                            nodes: [knownName, objectField.name]
                        )
                    )
                } else {
                    knownNames[fieldName] = objectField.name
                }
                return .continue
            default:
                return .continue
            }
        },
        leave: { node, _, _, _, _ in
            switch node.kind {
            case .objectValue:
                let prevKnownNames = knownNameStack.popLast()
                knownNames = prevKnownNames ?? [:]
                return .continue
            default:
                return .continue
            }
        }
    )
}
