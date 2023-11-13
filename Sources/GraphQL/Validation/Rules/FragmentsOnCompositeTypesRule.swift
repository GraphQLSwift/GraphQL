
/**
 * Fragments on composite type
 *
 * Fragments use a type condition to determine if they apply, since fragments
 * can only be spread into a composite type (object, interface, or union), the
 * type condition must also be a composite type.
 *
 * See https://spec.graphql.org/draft/#sec-Fragments-On-Composite-Types
 */
func FragmentsOnCompositeTypesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let fragment = node as? InlineFragment {
                if let typeCondition = fragment.typeCondition {
                    if let type = typeFromAST(schema: context.schema, inputTypeAST: typeCondition) {
                        if type is GraphQLCompositeType {
                            return .continue
                        }
                        let typeStr = typeCondition.name.value
                        context.report(
                            error: GraphQLError(
                                message:
                                "Fragment cannot condition on non composite type \"\(typeStr)\".",
                                nodes: [typeCondition]
                            )
                        )
                    }
                }
                return .continue
            }
            if let fragment = node as? FragmentDefinition {
                let typeCondition = fragment.typeCondition
                if let type = typeFromAST(schema: context.schema, inputTypeAST: typeCondition) {
                    if type is GraphQLCompositeType {
                        return .continue
                    }
                    let typeStr = typeCondition.name.value
                    context.report(
                        error: GraphQLError(
                            message:
                            "Fragment \"\(fragment.name.value)\" cannot condition on non composite type \"\(typeStr)\".",
                            nodes: [typeCondition]
                        )
                    )
                }
                return .continue
            }
            return .continue
        }
    )
}
