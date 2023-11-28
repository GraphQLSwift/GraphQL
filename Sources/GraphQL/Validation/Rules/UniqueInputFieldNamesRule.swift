
/**
 * Unique input field names
 *
 * A GraphQL input object value is only valid if all supplied fields are
 * uniquely named.
 *
 * See https://spec.graphql.org/draft/#sec-Input-Object-Field-Uniqueness
 */
func UniqueInputFieldNamesRule(context: ValidationContext) -> Visitor {
    var knownNameStack = [[String: Name]]()
    var knownNames = [String: Name]()

    return Visitor(
        enter: { node, _, _, _, _ in
            if node is ObjectValue {
                knownNameStack.append(knownNames)
                knownNames = [:]
                return .continue
            }
            if let objectField = node as? ObjectField {
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
            }
            return .continue
        },
        leave: { node, _, _, _, _ in
            if node is ObjectValue {
                let prevKnownNames = knownNameStack.popLast()
                knownNames = prevKnownNames ?? [:]
            }
            return .continue
        }
    )
}
