
/**
 * Unique field definition names
 *
 * A GraphQL complex type is only valid if all its fields are uniquely named.
 */
func UniqueFieldDefinitionNamesRule(
    context: SDLValidationContext
) -> Visitor {
    let schema = context.getSchema()
    let existingTypeMap = schema?.typeMap ?? [:]
    var knownFieldNames = [String: [String: Name]]()

    return Visitor(
        enter: { node, _, _, _, _ in
            if let node = node as? InputObjectTypeDefinition {
                checkFieldUniqueness(name: node.name, fields: node.fields)
            } else if let node = node as? InputObjectExtensionDefinition {
                checkFieldUniqueness(name: node.name, fields: node.definition.fields)
            } else if let node = node as? InterfaceTypeDefinition {
                checkFieldUniqueness(name: node.name, fields: node.fields)
            } else if let node = node as? InterfaceExtensionDefinition {
                checkFieldUniqueness(name: node.name, fields: node.definition.fields)
            } else if let node = node as? ObjectTypeDefinition {
                checkFieldUniqueness(name: node.name, fields: node.fields)
            } else if let node = node as? TypeExtensionDefinition {
                checkFieldUniqueness(name: node.name, fields: node.definition.fields)
            }
            return .continue
        }
    )

    func checkFieldUniqueness(
        name: Name,
        fields: [FieldDefinition]
    ) {
        let typeName = name.value
        var fieldNames = knownFieldNames[typeName] ?? [String: Name]()
        let fieldNodes = fields
        for fieldDef in fieldNodes {
            let fieldName = fieldDef.name.value
            if
                let existingType = existingTypeMap[typeName],
                hasField(type: existingType, fieldName: fieldName)
            {
                context.report(
                    error: GraphQLError(
                        message: "Field \"\(typeName).\(fieldName)\" already exists in the schema. It cannot also be defined in this type extension.",
                        nodes: [fieldDef.name]
                    )
                )
                continue
            }
            if let knownFieldName = fieldNames[fieldName] {
                context.report(
                    error: GraphQLError(
                        message: "Field \"\(typeName).\(fieldName)\" can only be defined once.",
                        nodes: [knownFieldName, fieldDef.name]
                    )
                )
            } else {
                fieldNames[fieldName] = fieldDef.name
            }
        }
        knownFieldNames[typeName] = fieldNames
    }

    func checkFieldUniqueness(
        name: Name,
        fields: [InputValueDefinition]
    ) {
        let typeName = name.value
        var fieldNames = knownFieldNames[typeName] ?? [String: Name]()
        let fieldNodes = fields
        for fieldDef in fieldNodes {
            let fieldName = fieldDef.name.value
            if
                let existingType = existingTypeMap[typeName],
                hasField(type: existingType, fieldName: fieldName)
            {
                context.report(
                    error: GraphQLError(
                        message: "Field \"\(typeName).\(fieldName)\" already exists in the schema. It cannot also be defined in this type extension.",
                        nodes: [fieldDef.name]
                    )
                )
                continue
            }
            if let knownFieldName = fieldNames[fieldName] {
                context.report(
                    error: GraphQLError(
                        message: "Field \"\(typeName).\(fieldName)\" can only be defined once.",
                        nodes: [knownFieldName, fieldDef.name]
                    )
                )
            } else {
                fieldNames[fieldName] = fieldDef.name
            }
        }
        knownFieldNames[typeName] = fieldNames
    }
}

func hasField(type: GraphQLNamedType, fieldName: String) -> Bool {
    if let type = type as? GraphQLObjectType {
        return (try? type.getFields()[fieldName]) != nil
    } else if let type = type as? GraphQLInterfaceType {
        return (try? type.getFields()[fieldName]) != nil
    } else if let type = type as? GraphQLInputObjectType {
        return (try? type.getFields()[fieldName]) != nil
    }
    return false
}
