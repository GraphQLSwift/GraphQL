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
        guard let nonNullType = type.ofType as? GraphQLInputType else {
            throw GraphQLError(
                message: "Expected GraphQLNonNull to contain an input type \(type)"
            )
        }
        return try astFromValue(value: value, type: nonNullType)
    }

    guard value != .null else {
        return nil
    }

    // Convert array to GraphQL list. If the GraphQLType is a list, but
    // the value is not an array, convert the value using the list's item type.
    if let type = type as? GraphQLList {
        guard let itemType = type.ofType as? GraphQLInputType else {
            throw GraphQLError(
                message: "Expected GraphQLList to contain an input type \(type)"
            )
        }

        if case let .array(value) = value {
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
        guard case let .dictionary(value) = value else {
            return nil
        }

        let fields = try type.getFields()
        var fieldASTs: [ObjectField] = []

        for (fieldName, field) in fields {
            let fieldType = field.type

            if
                let fieldValue = try astFromValue(
                    value: value[fieldName] ?? .null,
                    type: fieldType
                )
            {
                let field = ObjectField(name: Name(value: fieldName), value: fieldValue)
                fieldASTs.append(field)
            }
        }

        return ObjectValue(fields: fieldASTs)
    }

    guard let leafType = type as? GraphQLLeafType else {
        throw GraphQLError(
            message: "Expected scalar non-object type to be a leaf type: \(type)"
        )
    }

    // Since value is an internally represented value, it must be serialized
    // to an externally represented value before converting into an AST.
    let serialized = try leafType.serialize(value: value)

    guard serialized != .null else {
        return nil
    }

    // Others serialize based on their corresponding JavaScript scalar types.
    if case let .bool(bool) = serialized {
        return BooleanValue(value: bool)
    }

    // Others serialize based on their corresponding scalar types.
    if case let .bool(bool) = serialized {
        return BooleanValue(value: bool)
    }

    // JavaScript numbers can be Int or Float values.
    if case let .number(number) = serialized {
        switch number.storageType {
        case .bool:
            return BooleanValue(value: number.boolValue)
        case .int:
            return IntValue(value: String(number.intValue))
        case .double:
            return FloatValue(value: String(number.doubleValue))
        case .unknown:
            break
        }
    }

    if case let .string(string) = serialized {
        // Enum types use Enum literals.
        if type is GraphQLEnumType {
            return EnumValue(value: string)
        }

        // ID types can use Int literals.
        if type == GraphQLID, Int(string) != nil {
            return IntValue(value: string)
        }

        // Use JSON stringify, which uses the same string encoding as GraphQL,
        // then remove the quotes.
        struct Wrapper: Encodable {
            let map: Map
        }

        let data = try GraphQLJSONEncoder().encode(Wrapper(map: serialized))
        guard let string = String(data: data, encoding: .utf8) else {
            throw GraphQLError(
                message: "Unable to convert data to utf8 string: \(data)"
            )
        }
        return StringValue(value: String(string.dropFirst(8).dropLast(2)))
    }

    throw GraphQLError(message: "Cannot convert value to AST: \(serialized)")
}
