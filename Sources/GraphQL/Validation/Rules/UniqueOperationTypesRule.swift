
/**
 * Unique operation types
 *
 * A GraphQL document is only valid if it has only one type per operation.
 */
func UniqueOperationTypesRule(
    context: SDLValidationContext
) -> Visitor {
    let schema = context.getSchema()
    var definedOperationTypes: [OperationType: OperationTypeDefinition] = .init()
    let existingOperationTypes = {
        var result = [OperationType: GraphQLObjectType]()
        if let queryType = schema?.queryType {
            result[.query] = queryType
        }
        if let mutationType = schema?.mutationType {
            result[.mutation] = mutationType
        }
        if let subscriptionType = schema?.subscriptionType {
            result[.subscription] = subscriptionType
        }
        return result
    }()

    return Visitor(
        enter: { node, _, _, _, _ in
            if let operation = node as? SchemaDefinition {
                checkOperationTypes(operation.operationTypes)
            } else if let operation = node as? SchemaExtensionDefinition {
                checkOperationTypes(operation.definition.operationTypes)
            }
            return .continue
        }
    )

    func checkOperationTypes(
        _ operationTypesNodes: [OperationTypeDefinition]
    ) {
        for operationType in operationTypesNodes {
            let operation = operationType.operation

            if existingOperationTypes[operation] != nil {
                context.report(
                    error: GraphQLError(
                        message: "Type for \(operation) already defined in the schema. It cannot be redefined.",
                        nodes: [operationType]
                    )
                )
            } else if let alreadyDefinedOperationType = definedOperationTypes[operation] {
                context.report(
                    error: GraphQLError(
                        message: "There can be only one \(operation) type in schema.",
                        nodes: [alreadyDefinedOperationType, operationType]
                    )
                )
            } else {
                definedOperationTypes[operation] = operationType
            }
        }
    }
}
