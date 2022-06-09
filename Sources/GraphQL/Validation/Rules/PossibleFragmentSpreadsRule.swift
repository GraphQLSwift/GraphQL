/**
 * Possible fragment spread
 *
 * A fragment spread is only valid if the type condition could ever possibly
 * be true: if there is a non-empty intersection of the possible parent types,
 * and possible types which pass the type condition.
 */
struct PossibleFragmentSpreadsRule: ValidationRule {
    let context: ValidationContext
    
    func enter(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InlineFragment> {
        guard
            let fragType = context.type as? (any GraphQLCompositeType),
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
                nodes: [inlineFragment]
            )
        )
        return .continue
    }
    
    func enter(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread> {
        
        let fragName = fragmentSpread.name.value
        
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
                nodes: [fragmentSpread]
            )
        )
        return .continue
    }
}

func getFragmentType(
    context: ValidationContext,
    name: String
) -> (any GraphQLCompositeType)? {
    if let fragment = context.getFragment(name: name) {
        let type = typeFromAST(
            schema: context.schema,
            inputTypeAST: .namedType(fragment.typeCondition)
        )
        
        if let type = type as? (any GraphQLCompositeType) {
            return type
        }
    }
    
    return nil
}
