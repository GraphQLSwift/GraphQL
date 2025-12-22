
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
            switch node.kind {
            case .operationDefinition:
                let operation = node as! OperationDefinition
                for fragment in context.getRecursivelyReferencedFragments(operation: operation) {
                    fragmentNameUsed.insert(fragment.name.value)
                }
                return .continue
            case .fragmentDefinition:
                let fragment = node as! FragmentDefinition
                fragmentDefs.append(fragment)
                return .continue
            default:
                return .continue
            }
        },
        leave: { node, _, _, _, _ -> VisitResult in
            // Use Document as proxy for the end of the visitation
            switch node.kind {
            case .document:
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
                return .continue
            default:
                return .continue
            }
        }
    )
}
