import Foundation

/**
 * Known fragment names
 *
 * A GraphQL document is only valid if all `...Fragment` fragment spreads refer
 * to fragments defined in the same document.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-spread-target-defined
 */
func KnownFragmentNamesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .fragmentSpread:
                let fragmentReference = node as! FragmentSpread
                let fragmentName = fragmentReference.name.value
                let fragmentDefinition = context.getFragment(name: fragmentName)

                if fragmentDefinition == nil {
                    context.report(error: GraphQLError(
                        message: "Unknown fragment \"\(fragmentName)\".",
                        nodes: [fragmentReference.name]
                    ))
                }
                return .continue
            default:
                return .continue
            }
        }
    )
}
