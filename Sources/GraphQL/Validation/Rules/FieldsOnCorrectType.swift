func undefinedFieldMessage(
    fieldName: String,
    type: String,
    suggestedTypeNames: [String],
    suggestedFieldNames: [String]
) -> String {
    var message = "Cannot query field \"\(fieldName)\" on type \"\(type)\"."

    if !suggestedTypeNames.isEmpty {
        let suggestions = quotedOrList(items: suggestedTypeNames)
        message += " Did you mean to use an inline fragment on \(suggestions)?"
    } else if !suggestedFieldNames.isEmpty {
        let suggestions = quotedOrList(items: suggestedFieldNames)
        message += " Did you mean \(suggestions)?"
    }

    return message
}

/**
 * Fields on correct type
 *
 * A GraphQL document is only valid if all fields selected are defined by the
 * parent type, or are an allowed meta field such as __typename.
 */
func FieldsOnCorrectType(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, key, parent, path, ancestors in
            if let node = node as? Field {
                if let type = context.parentType {
                    let fieldDef = context.fieldDef
                    if fieldDef == nil {
                        // This field doesn't exist, lets look for suggestions.
                        let schema = context.schema
                        let fieldName = node.name.value

                        // First determine if there are any suggested types to condition on.
                        let suggestedTypeNames = getSuggestedTypeNames(
                            schema: schema,
                            type: type,
                            fieldName: fieldName
                        )

                        // If there are no suggested types, then perhaps this was a typo?
                        let suggestedFieldNames = !suggestedTypeNames.isEmpty ? [] : getSuggestedFieldNames(
                            schema: schema,
                            type: type,
                            fieldName: fieldName
                        )

                        // Report an error, including helpful suggestions.
                        context.report(error: GraphQLError(
                            message: undefinedFieldMessage(
                                fieldName: fieldName,
                                type: type.name,
                                suggestedTypeNames: suggestedTypeNames,
                                suggestedFieldNames: suggestedFieldNames
                            ),
                            nodes: [node]
                        ))
                    }
                }
            }

            return .continue
        }
    )
}

/**
 * Go through all of the implementations of type, as well as the interfaces
 * that they implement. If any of those types include the provided field,
 * suggest them, sorted by how often the type is referenced,  starting
 * with Interfaces.
 */
func getSuggestedTypeNames(
    schema: GraphQLSchema,
    type: GraphQLOutputType,
    fieldName: String
) -> [String] {
    if let type = type as? GraphQLAbstractType {
        var suggestedObjectTypes: [String] = []
        var interfaceUsageCount: [String: Int] = [:]

        for possibleType in schema.getPossibleTypes(abstractType: type) {

            if possibleType.fields[fieldName] == nil {
                return []
            }

            // This object type defines this field.
            suggestedObjectTypes.append(possibleType.name)

            for possibleInterface in possibleType.interfaces {
                if possibleInterface.fields[fieldName] == nil {
                    return []
                }
                // This interface type defines this field.
                interfaceUsageCount[possibleInterface.name] = (interfaceUsageCount[possibleInterface.name] ?? 0) + 1
            }
        }

        // Suggest interface types based on how common they are.
        let suggestedInterfaceTypes = interfaceUsageCount.keys.sorted {
            interfaceUsageCount[$1]! - interfaceUsageCount[$0]! >= 0
        }

        // Suggest both interface and object types.
        return suggestedInterfaceTypes + suggestedObjectTypes
    }
    
    // Otherwise, must be an Object type, which does not have possible fields.
    return []
}

/**
 * For the field name provided, determine if there are any similar field names
 * that may be the result of a typo.
 */
func getSuggestedFieldNames(
    schema: GraphQLSchema,
    type: GraphQLOutputType,
    fieldName: String
) -> [String] {
    if let type = type as? GraphQLObjectType {
        let possibleFieldNames = Array(type.fields.keys)
        return suggestionList(
            input: fieldName,
            options: possibleFieldNames
        )
    }

    if let type = type as? GraphQLInterfaceType {
        let possibleFieldNames = Array(type.fields.keys)
        return suggestionList(
            input: fieldName,
            options: possibleFieldNames
        )
    }

    // Otherwise, must be a Union type, which does not define fields.
    return []
}
