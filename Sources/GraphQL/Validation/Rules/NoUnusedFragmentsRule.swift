
/**
 * No unused fragments
 *
 * A GraphQL document is only valid if all fragment definitions are spread
 * within operations, or spread within other fragments spread within operations.
 *
 * See https://spec.graphql.org/draft/#sec-Fragments-Must-Be-Used
 */
func NoUnusedFragmentsRule(context: ValidationContext) -> Visitor {
    var fragmentNameUsed = Set<String>()
    var fragmentDefs = [FragmentDefinition]()

    return Visitor(
        enter: { node, _, _, _, _ in
            if let operation = node as? OperationDefinition {
                for fragment in context.getRecursivelyReferencedFragments(operation: operation) {
                    fragmentNameUsed.insert(fragment.name.value)
                }
                return .continue
            }

            if let fragment = node as? FragmentDefinition {
                fragmentDefs.append(fragment)
                return .continue
            }
            return .continue
        },
        leave: { node, _, _, _, _ -> VisitResult in
            // Use Document as proxy for the end of the visitation
            if node is Document {
                for fragmentDef in fragmentDefs {
                    let fragName = fragmentDef.name.value
                    if !fragmentNameUsed.contains(fragName) {
                        context.report(
                            error: GraphQLError(
                                message: "Fragment \"\(fragName)\" is never used.",
                                nodes: [fragmentDef]
                            )
                        )
                    }
                }
            }
            return .continue
        }
    )
}
