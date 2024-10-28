
/**
 * Unique enum value names
 *
 * A GraphQL enum type is only valid if all its values are uniquely named.
 */
func UniqueEnumValueNamesRule(
    context: SDLValidationContext
) -> Visitor {
    let schema = context.getSchema()
    let existingTypeMap = schema?.typeMap ?? [:]
    var knownValueNames = [String: [String: Name]]()

    return Visitor(
        enter: { node, _, _, _, _ in
            if let definition = node as? EnumTypeDefinition {
                checkValueUniqueness(node: definition)
            } else if let definition = node as? EnumExtensionDefinition {
                checkValueUniqueness(node: definition.definition)
            }
            return .continue
        }
    )

    func checkValueUniqueness(node: EnumTypeDefinition) {
        let typeName = node.name.value
        var valueNames = knownValueNames[typeName] ?? [:]
        let valueNodes = node.values
        for valueDef in valueNodes {
            let valueName = valueDef.name.value

            let existingType = existingTypeMap[typeName]
            if
                let existingType = existingType as? GraphQLEnumType,
                existingType.nameLookup[valueName] != nil
            {
                context.report(
                    error: GraphQLError(
                        message: "Enum value \"\(typeName).\(valueName)\" already exists in the schema. It cannot also be defined in this type extension.",
                        nodes: [valueDef.name]
                    )
                )
                continue
            }

            if let knownValueName = valueNames[valueName] {
                context.report(
                    error: GraphQLError(
                        message: "Enum value \"\(typeName).\(valueName)\" can only be defined once.",
                        nodes: [knownValueName, valueDef.name]
                    )
                )
            } else {
                valueNames[valueName] = valueDef.name
            }
        }
        knownValueNames[typeName] = valueNames
    }
}
