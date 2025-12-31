
/**
 * Lone Schema definition
 *
 * A GraphQL document is only valid if it contains only one schema definition.
 */
func LoneSchemaDefinitionRule(context: SDLValidationContext) -> Visitor {
    let oldSchema = context.getSchema()
    let alreadyDefined =
        oldSchema?.astNode != nil ||
        oldSchema?.queryType != nil ||
        oldSchema?.mutationType != nil ||
        oldSchema?.subscriptionType != nil

    var schemaDefinitionsCount = 0
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .schemaDefinition:
                let node = node as! SchemaDefinition
                if alreadyDefined {
                    context.report(
                        error: GraphQLError(
                            message: "Cannot define a new schema within a schema extension.",
                            nodes: [node]
                        )
                    )
                }

                if schemaDefinitionsCount > 0 {
                    context.report(
                        error: GraphQLError(
                            message: "Must provide only one schema definition.",
                            nodes: [node]
                        )
                    )
                }

                schemaDefinitionsCount = schemaDefinitionsCount + 1
                return .continue
            default:
                return .continue
            }
        }
    )
}
