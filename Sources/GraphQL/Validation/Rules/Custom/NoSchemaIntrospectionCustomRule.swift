
/**
 * Prohibit introspection queries
 *
 * A GraphQL document is only valid if all fields selected are not fields that
 * return an introspection type.
 *
 * Note: This rule is optional and is not part of the Validation section of the
 * GraphQL Specification. This rule effectively disables introspection, which
 * does not reflect best practices and should only be done if absolutely necessary.
 */
public func NoSchemaIntrospectionCustomRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .field:
                let node = node as! Field
                if
                    let type = getNamedType(type: context.type),
                    isIntrospectionType(type: type)
                {
                    context.report(
                        error: GraphQLError(
                            message: "GraphQL introspection has been disabled, but the requested query contained the field \(node.name.value)",
                            nodes: [node]
                        )
                    )
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
