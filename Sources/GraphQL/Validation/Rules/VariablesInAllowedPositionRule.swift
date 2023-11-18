
/**
 * Variables in allowed position
 *
 * Variable usages must be compatible with the arguments they are passed to.
 *
 * See https://spec.graphql.org/draft/#sec-All-Variable-Usages-are-Allowed
 */
func VariablesInAllowedPositionRule(context: ValidationContext) -> Visitor {
    var varDefMap: [String: VariableDefinition] = [:]
    return Visitor(
        enter: { node, _, _, _, _ in
            switch node {
            case _ as OperationDefinition:
                varDefMap = [:]
            case let variableDefinition as VariableDefinition:
                varDefMap[variableDefinition.variable.name.value] = variableDefinition
            default:
                break
            }
            return .continue
        },
        leave: { node, _, _, _, _ in
            switch node {
            case let operation as OperationDefinition:
                let usages = context.getRecursiveVariableUsages(operation: operation)

                for usage in usages {
                    let varName = usage.node.name.value
                    let schema = context.schema

                    if
                        let varDef = varDefMap[varName],
                        let type = usage.type,
                        let varType = typeFromAST(schema: schema, inputTypeAST: varDef.type)
                    {
                        // A var type is allowed if it is the same or more strict (e.g. is
                        // a subtype of) than the expected type. It can be more strict if
                        // the variable type is non-null when the expected type is nullable.
                        // If both are list types, the variable item type can be more strict
                        // than the expected item type (contravariant).
                        let isAllowed = (try? allowedVariableUsage(
                            schema: schema,
                            varType: varType,
                            varDefaultValue: varDef.defaultValue,
                            locationType: type,
                            locationDefaultValue: usage.defaultValue
                        )) ?? false
                        if !isAllowed {
                            context.report(
                                error: GraphQLError(
                                    message: "Variable \"$\(varName)\" of type \"\(varType)\" used in position expecting type \"\(type)\".",
                                    nodes: [varDef, usage.node]
                                )
                            )
                        }
                    }
                }
            default:
                break
            }
            return .continue
        }
    )
}

/**
 * Returns true if the variable is allowed in the location it was found,
 * which includes considering if default values exist for either the variable
 * or the location at which it is located.
 */
func allowedVariableUsage(
    schema: GraphQLSchema,
    varType: GraphQLType,
    varDefaultValue: Value?,
    locationType: GraphQLType,
    locationDefaultValue: Map?
) throws -> Bool {
    if let locationType = locationType as? GraphQLNonNull, !(varType is GraphQLNonNull) {
        let hasNonNullVariableDefaultValue = varDefaultValue != nil && varDefaultValue?
            .kind != .nullValue
        let hasLocationDefaultValue = locationDefaultValue != .undefined
        if !hasNonNullVariableDefaultValue && !hasLocationDefaultValue {
            return false
        }
        let nullableLocationType = locationType.ofType
        return try isTypeSubTypeOf(schema, varType, nullableLocationType)
    }
    return try isTypeSubTypeOf(schema, varType, locationType)
}
