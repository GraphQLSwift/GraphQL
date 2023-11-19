
/**
 * Known directives
 *
 * A GraphQL document is only valid if all `@directives` are known by the
 * schema and legally positioned.
 *
 * See https://spec.graphql.org/draft/#sec-Directives-Are-Defined
 */
func KnownDirectivesRule(context: ValidationContext) -> Visitor {
    var locationsMap = [String: [String]]()

    let schema = context.schema
    let definedDirectives = schema.directives
    for directive in definedDirectives {
        locationsMap[directive.name] = directive.locations.map { $0.rawValue }
    }

    let astDefinitions = context.ast.definitions
    for def in astDefinitions {
        if let directive = def as? DirectiveDefinition {
            locationsMap[directive.name.value] = directive.locations.map { $0.value }
        }
    }

    return Visitor(
        enter: { node, _, _, _, ancestors in
            if let node = node as? Directive {
                let name = node.name.value
                let locations = locationsMap[name]

                guard let locations = locations else {
                    context.report(
                        error: GraphQLError(
                            message: "Unknown directive \"@\(name)\".",
                            nodes: [node]
                        )
                    )
                    return .continue
                }

                let candidateLocation = getDirectiveLocationForASTPath(ancestors)
                if
                    let candidateLocation = candidateLocation,
                    !locations.contains(candidateLocation.rawValue)
                {
                    context.report(
                        error: GraphQLError(
                            message: "Directive \"@\(name)\" may not be used on \(candidateLocation.rawValue).",
                            nodes: [node]
                        )
                    )
                }
            }
            return .continue
        }
    )
}

func getDirectiveLocationForASTPath(_ ancestors: [NodeResult]) -> DirectiveLocation? {
    guard let last = ancestors.last, case let .node(appliedTo) = last else {
        return nil
    }

    switch appliedTo {
    case let appliedTo as OperationDefinition:
        return getDirectiveLocationForOperation(appliedTo.operation)
    case is Field:
        return DirectiveLocation.field
    case is FragmentSpread:
        return DirectiveLocation.fragmentSpread
    case is InlineFragment:
        return DirectiveLocation.inlineFragment
    case is FragmentDefinition:
        return DirectiveLocation.fragmentDefinition
    case is VariableDefinition:
        return DirectiveLocation.variableDefinition
    case is SchemaDefinition:
        return DirectiveLocation.schema
    case is ScalarTypeDefinition, is ScalarExtensionDefinition:
        return DirectiveLocation.scalar
    case is ObjectTypeDefinition:
        return DirectiveLocation.object
    case is FieldDefinition:
        return DirectiveLocation.fieldDefinition
    case is InterfaceTypeDefinition, is InterfaceExtensionDefinition:
        return DirectiveLocation.interface
    case is UnionTypeDefinition, is UnionExtensionDefinition:
        return DirectiveLocation.union
    case is EnumTypeDefinition, is EnumExtensionDefinition:
        return DirectiveLocation.enum
    case is EnumValueDefinition:
        return DirectiveLocation.enumValue
    case is InputObjectTypeDefinition, is InputObjectExtensionDefinition:
        return DirectiveLocation.inputObject
    case is InputValueDefinition:
        guard ancestors.count >= 3 else {
            return nil
        }
        let parentNode = ancestors[ancestors.count - 3]
        guard case let .node(parentNode) = parentNode else {
            return nil
        }
        return parentNode.kind == .inputObjectTypeDefinition
            ? DirectiveLocation.inputFieldDefinition
            : DirectiveLocation.argumentDefinition
    // Not reachable, all possible types have been considered.
    default:
        return nil
    }
}

func getDirectiveLocationForOperation(_ operation: OperationType) -> DirectiveLocation {
    switch operation {
    case .query:
        return DirectiveLocation.query
    case .mutation:
        return DirectiveLocation.mutation
    case .subscription:
        return DirectiveLocation.subscription
    }
}
