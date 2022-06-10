import Foundation

/**
 * Known fragment names
 *
 * A GraphQL document is only valid if all `...Fragment` fragment spreads refer
 * to fragments defined in the same document.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-spread-target-defined
 */
struct KnownFragmentNamesRule: ValidationRule {
    let context: ValidationContext
    
    func enter(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread> {
        let fragmentName = fragmentSpread.name.value
        if context.getFragment(name: fragmentName) == nil {
            context.report(
                error: GraphQLError(
                    message: "Unknown fragment \(fragmentName)",
                    nodes: [fragmentSpread.name]
                )
            )
        }
        return .continue
    }
}
