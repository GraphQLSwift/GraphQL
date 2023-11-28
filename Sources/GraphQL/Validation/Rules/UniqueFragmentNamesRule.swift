
/**
 * Unique fragment names
 *
 * A GraphQL document is only valid if all defined fragments have unique names.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-Name-Uniqueness
 */
func UniqueFragmentNamesRule(context: ValidationContext) -> Visitor {
    var knownFragmentNames = [String: Name]()
    return Visitor(
        enter: { node, _, _, _, _ in
            if let fragment = node as? FragmentDefinition {
                let fragmentName = fragment.name
                if let knownFragmentName = knownFragmentNames[fragmentName.value] {
                    context.report(
                        error: GraphQLError(
                            message: "There can be only one fragment named \"\(fragmentName.value)\".",
                            nodes: [knownFragmentName, fragmentName]
                        )
                    )
                } else {
                    knownFragmentNames[fragmentName.value] = fragmentName
                }
            }
            return .continue
        }
    )
}
