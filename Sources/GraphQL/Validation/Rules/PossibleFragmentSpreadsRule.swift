/**
 * Possible fragment spread
 *
 * A fragment spread is only valid if the type condition could ever possibly
 * be true: if there is a non-empty intersection of the possible parent types,
 * and possible types which pass the type condition.
 */
func PossibleFragmentSpreadsRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, key, parent, path, ancestors in
            if let node = node as? InlineFragment {
                guard
                    let fragType = context.type as? GraphQLCompositeType,
                    let parentType = context.parentType
                    else {
                        return .continue
                }
                
                let isThereOverlap = doTypesOverlap(
                    schema: context.schema,
                    typeA: fragType,
                    typeB: parentType
                )
                
                guard !isThereOverlap else {
                    return .continue
                }
                
                context.report(
                    error: GraphQLError(
                        message: "Fragment cannot be spread here as objects of type \"\(parentType)\" can never be of type \"\(fragType)\".",
                        nodes: [node]
                    )
                )
            }
            
            if let node = node as? FragmentSpread {
                let fragName = node.name.value
                
                guard
                    let fragType = getFragmentType(context: context, name: fragName),
                    let parentType = context.parentType
                else {
                    return .continue
                }

                let isThereOverlap = doTypesOverlap(
                    schema: context.schema,
                    typeA: fragType,
                    typeB: parentType
                )
                
                guard !isThereOverlap else {
                    return .continue
                }
                
                context.report(
                    error: GraphQLError(
                        message: "Fragment \"\(fragName)\" cannot be spread here as objects of type \"\(parentType)\" can never be of type \"\(fragType)\".",
                        nodes: [node]
                    )
                )
            }
            
            return .continue
        }
    )
}

func getFragmentType(
    context: ValidationContext,
    name: String
) -> GraphQLCompositeType? {
    if let fragment = context.getFragment(name: name) {
        let type = typeFromAST(
            schema: context.schema,
            inputTypeAST: fragment.typeCondition
        )
        
        if let type = type as? GraphQLCompositeType {
            return type
        }
    }
    
    return nil
}
