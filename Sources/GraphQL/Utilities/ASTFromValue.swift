/**
 * Produces a GraphQL Value AST given a Map value.
 *
 * A GraphQL type must be provided, which will be used to interpret different
 * JavaScript values.
 *
 *     | Map Value     | GraphQL Value        |
 *     | ------------- | -------------------- |
 *     | .dictionary   | Input Object         |
 *     | .array        | List                 |
 *     | .bool         | Boolean              |
 *     | .string       | String / Enum Value  |
 *     | .int          | Int                  |
 *     | .double       | Float                |
 *
 */
func astFromValue(
    value: Map,
    type: GraphQLInputType
) throws -> Value? {
    if let type = type as? GraphQLNonNull {
        // Note: we're not checking that the result is non-null.
        // This function is not responsible for validating the input value.
        return try astFromValue(value: value, type: type.ofType as! GraphQLInputType)
    }

    guard value != .null else {
        return nil
    }

    // Convert JavaScript array to GraphQL list. If the GraphQLType is a list, but
    // the value is not an array, convert the value using the list's item type.
    if let type = type as? GraphQLList {
        let itemType = type.ofType as! GraphQLInputType

        if case .array(let value) = value {
            var valuesASTs: [Value] = []

            for item in value {
                if let itemAST = try astFromValue(value: item, type: itemType) {
                    valuesASTs.append(itemAST)
                }
            }

            return ListValue(values: valuesASTs)
        }

        return try astFromValue(value: value, type: itemType)
    }

    // Populate the fields of the input object by creating ASTs from each value
    // in the JavaScript object according to the fields in the input type.
    if let type = type as? GraphQLInputObjectType {
        guard case .dictionary(let value) = value else {
            return nil
        }

        let fields = type.fields
        var fieldASTs: [ObjectField] = []

        for (fieldName, field) in fields {
            let fieldType = field.type

            if let fieldValue = try astFromValue(value: value[fieldName] ?? .null, type: fieldType) {
                let field = ObjectField(name: Name(value: fieldName), value: fieldValue)
                fieldASTs.append(field)
            }
        }

        return ObjectValue(fields: fieldASTs)
    }

    guard let leafType = type as? GraphQLLeafType else {
        throw GraphQLError(
            message: "Must provide Input Type, cannot use: \(type)"
        )
    }

    // Since value is an internally represented value, it must be serialized
    // to an externally represented value before converting into an AST.
    let serialized = try leafType.serialize(value: value)

    guard serialized != .null else {
        return nil
    }

    // Others serialize based on their corresponding JavaScript scalar types.
    if case .bool(let bool) = serialized {
        return BooleanValue(value: bool)
    }

    // JavaScript numbers can be Int or Float values.
    if case .int(let int) = serialized {
        return IntValue(value: String(int))
    }

    if case .double(let double) = serialized {
        return FloatValue(value: String(double))
    }

    if case .string(let string) = serialized {
        // Enum types use Enum literals.
        if type is GraphQLEnumType {
            return EnumValue(value: string)
        }

        // ID types can use Int literals.
        if type == GraphQLID && Int(string) != nil {
            return IntValue(value: string)
        }
        
        // Use JSON stringify, which uses the same string encoding as GraphQL,
        // then remove the quotes.
        return StringValue(value: String(serialized.description.dropFirst().dropLast()))
    }
    
    throw GraphQLError(message: "Cannot convert value to AST: \(serialized)")
}
