import OrderedCollections

/**
 * Produces a Map value given a GraphQL Value AST.
 *
 * A GraphQL type must be provided, which will be used to interpret different
 * GraphQL Value literals.
 *
 * | GraphQL Value        | Map Value     |
 * | -------------------- | ------------- |
 * | Input Object         | .dictionary   |
 * | List                 | .array        |
 * | Boolean              | .bool         |
 * | String               | .string       |
 * | Int                  | .int          |
 * | Float                | .float        |
 * | Enum Value           | .string       |
 *
 */
func valueFromAST(valueAST: Value, type: GraphQLInputType, variables: [String: Map] = [:]) throws -> Map {
    if let nonNull = type as? GraphQLNonNull {
        // Note: we're not checking that the result of valueFromAST is non-null.
        // We're assuming that this query has been validated and the value used
        // here is of the correct type.
        guard let nonNullType = nonNull.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "NonNull must wrap an input type")
        }
        return try valueFromAST(valueAST: valueAST, type: nonNullType, variables: variables)
    }

    if let variable = valueAST as? Variable {
        let variableName = variable.name.value

        //    if (!variables || !variables.hasOwnProperty(variableName)) {
        //      return null;
        //    }
        // Note: we're not doing any checking that this variable is correct. We're
        // assuming that this query has been validated and the variable usage here
        // is of the correct type.
        if let variable = variables[variableName] {
            return variable
        } else {
            return .undefined
        }
    }

    if let list = type as? GraphQLList {
        guard let itemType = list.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "Input list must wrap an input type")
        }

        if let listValue = valueAST as? ListValue {
            let values = try listValue.values.map { item in
                try valueFromAST(
                    valueAST: item,
                    type: itemType,
                    variables: variables
                )
            }
            return .array(values)
        }
        
        // Convert solitary value into single-value array
        return .array([
            try valueFromAST(
                valueAST: valueAST,
                type: itemType,
                variables: variables
            )
        ])
    }

    if let objectType = type as? GraphQLInputObjectType {
        guard let objectValue = valueAST as? ObjectValue else {
            throw GraphQLError(message: "Must be object type")
        }

        let fields = objectType.fields
        let fieldASTs = objectValue.fields.keyMap({ $0.name.value })
        
        var object = OrderedDictionary<String, Map>()
        for (fieldName, field) in fields {
            if let fieldAST = fieldASTs[fieldName] {
                object[fieldName] = try valueFromAST(
                    valueAST: fieldAST.value,
                    type: field.type,
                    variables: variables
                )
            } else {
                // If AST doesn't contain field, it is undefined
                if let defaultValue = field.defaultValue {
                    object[fieldName] = defaultValue
                } else {
                    object[fieldName] = .undefined
                }
            }
        }
        return .dictionary(object)
    }
    
    if let leafType = type as? GraphQLLeafType {
        return try leafType.parseLiteral(valueAST: valueAST)
    }
    
    throw GraphQLError(message: "Must be input type")
}
