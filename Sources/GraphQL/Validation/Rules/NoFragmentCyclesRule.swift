
/**
 * No fragment cycles
 *
 * The graph of fragment spreads must not form any cycles including spreading itself.
 * Otherwise an operation could infinitely spread or infinitely execute on cycles in the underlying data.
 *
 * See https://spec.graphql.org/draft/#sec-Fragment-spreads-must-not-form-cycles
 */
func NoFragmentCyclesRule(context: ValidationContext) -> Visitor {
    // Tracks already visited fragments to maintain O(N) and to ensure that cycles
    // are not redundantly reported.
    var visitedFrags = Set<String>()

    // Array of AST nodes used to produce meaningful errors
    var spreadPath = [FragmentSpread]()

    // Position in the spread path
    var spreadPathIndexByName = [String: Int]()

    // This does a straight-forward DFS to find cycles.
    // It does not terminate when a cycle was found but continues to explore
    // the graph to find all possible cycles.
    func detectCycleRecursive(fragment: FragmentDefinition) {
        if visitedFrags.contains(fragment.name.value) {
            return
        }

        let fragmentName = fragment.name.value
        visitedFrags.insert(fragmentName)

        let spreadNodes = context.getFragmentSpreads(node: fragment.selectionSet)
        if spreadNodes.count == 0 {
            return
        }

        spreadPathIndexByName[fragmentName] = spreadPath.count

        for spreadNode in spreadNodes {
            let spreadName = spreadNode.name.value
            let cycleIndex = spreadPathIndexByName[spreadName]

            spreadPath.append(spreadNode)
            if let cycleIndex = cycleIndex {
                let cyclePath = Array(spreadPath[cycleIndex ..< spreadPath.count])
                let viaPath = cyclePath[0 ..< max(cyclePath.count - 1, 0)]
                    .map { "\"\($0.name.value)\"" }.joined(separator: ", ")

                context.report(
                    error: GraphQLError(
                        message: "Cannot spread fragment \"\(spreadName)\" within itself" +
                            (viaPath != "" ? " via \(viaPath)." : "."),
                        nodes: cyclePath
                    )
                )
            } else {
                if let spreadFragment = context.getFragment(name: spreadName) {
                    detectCycleRecursive(fragment: spreadFragment)
                }
            }
            spreadPath.removeLast()
        }

        spreadPathIndexByName[fragmentName] = nil
    }

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .operationDefinition:
                return .skip
            case .fragmentDefinition:
                let fragmentDefinition = node as! FragmentDefinition
                detectCycleRecursive(fragment: fragmentDefinition)
                return .skip
            default:
                return .continue
            }
        }
    )
}
