import OrderedCollections

/**
 * Produces a JavaScript value given a GraphQL Value AST.
 *
 * Unlike `valueFromAST()`, no type is provided. The resulting map
 * will reflect the provided GraphQL value AST.
 *
 * | GraphQL Value        | Map Value |
 * | -------------------- | ---------------- |
 * | Input Object         | .dictionary           |
 * | List                 | .array            |
 * | Boolean              | .boolean          |
 * | String / Enum        | .string           |
 * | Int                  | .int          |
 * | Float                | .float        |
 * | Null                 | .null             |
 *
 */
public func valueFromASTUntyped(
    valueAST: Value,
    variables: [String: Map] = [:]
) throws -> Map {
    switch valueAST {
    case _ as NullValue:
        return .null
    case let value as IntValue:
        guard let int = Int(value.value) else {
            throw GraphQLError(message: "Int cannot represent non-integer value: \(value)")
        }
        return .int(int)
    case let value as FloatValue:
        guard let double = Double(value.value) else {
            throw GraphQLError(message: "Float cannot represent non numeric value: \(value)")
        }
        return .double(double)
    case let value as StringValue:
        return .string(value.value)
    case let value as EnumValue:
        return .string(value.value)
    case let value as BooleanValue:
        return .bool(value.value)
    case let value as ListValue:
        let array = try value.values.map { try valueFromASTUntyped(
            valueAST: $0,
            variables: variables
        ) }
        return .array(array)
    case let value as ObjectValue:
        var dictionary = OrderedDictionary<String, Map>()
        try value.fields.forEach { field in
            dictionary[field.name.value] = try valueFromASTUntyped(
                valueAST: field.value,
                variables: variables
            )
        }
        return .dictionary(dictionary)
    case let value as Variable:
        if let variable = variables[value.name.value] {
            return variable
        } else {
            return .undefined
        }
    default:
        return .undefined
    }
}
