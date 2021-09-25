import Foundation

/**
 * Prepares an object map of variableValues of the correct type based on the
 * provided variable definitions and arbitrary input. If the input cannot be
 * parsed to match the variable definitions, a GraphQLError will be thrown.
 */
func getVariableValues(schema: GraphQLSchema, definitionASTs: [VariableDefinition], inputs: [String: Map]) throws -> [String: Map] {
    return try definitionASTs.reduce([:]) { values, defAST in
        var valuesCopy = values
        let varName = defAST.variable.name.value

        valuesCopy[varName] = try getVariableValue(
            schema: schema,
            definitionAST: defAST,
            input: inputs[varName] ?? .null
        )

        return valuesCopy
    }
}


/**
 * Prepares an object map of argument values given a list of argument
 * definitions and list of argument AST nodes.
 */
func getArgumentValues(argDefs: [GraphQLArgumentDefinition], argASTs: [Argument]?, variableValues: [String: Map] = [:]) throws -> Map {
    guard let argASTs = argASTs else {
        return [:]
    }

    let argASTMap = argASTs.keyMap({ $0.name.value })

    return try argDefs.reduce([:]) { result, argDef in
        var result = result
        let name = argDef.name
        let argAST = argASTMap[name]
        
        if let argAST = argAST {
            let valueAST = argAST.value

            let value = try valueFromAST(
                valueAST: valueAST,
                type: argDef.type,
                variables: variableValues
            )

            result[name] = value
        } else {
            result[name] = .null
        }

        return result
    }
}


/**
 * Given a variable definition, and any value of input, return a value which
 * adheres to the variable definition, or throw an error.
 */
func getVariableValue(schema: GraphQLSchema, definitionAST: VariableDefinition, input: Map) throws -> Map {
    let type = typeFromAST(schema: schema, inputTypeAST: definitionAST.type)
    let variable = definitionAST.variable

    guard let inputType = type as? GraphQLInputType else {
        throw GraphQLError(
            message:
            "Variable \"$\(variable.name.value)\" expected value of type " +
            "\"\(definitionAST.type)\" which cannot be used as an input type.",
            nodes: [definitionAST]
        )
    }
    
    if input == .undefined {
        if let defaultValue = definitionAST.defaultValue {
            return try valueFromAST(valueAST: defaultValue, type: inputType)
        } else {
            if inputType is GraphQLNonNull {
                throw GraphQLError(message: "Non-nullable type \(inputType) must be provided.")
            } else {
                return .undefined
            }
        }
    }
    
    let errors = try isValidValue(value: input, type: inputType)
    guard errors.isEmpty else {
        let message = !errors.isEmpty ? "\n" + errors.joined(separator: "\n") : ""
        throw GraphQLError(
            message:
            "Variable \"$\(variable.name.value)\" got invalid value " +
            "\(input).\(message)", // TODO: "\(JSON.stringify(input)).\(message)",
            nodes: [definitionAST]
        )
    }
    
    return try coerceValue(type: inputType, value: input)
}

/**
 * Given a type and any value, return a runtime value coerced to match the type.
 */
func coerceValue(type: GraphQLInputType, value: Map) throws -> Map {
    if let nonNull = type as? GraphQLNonNull {
        // Note: we're not checking that the result of coerceValue is non-null.
        // We only call this function after calling isValidValue.
        return try coerceValue(type: nonNull.ofType as! GraphQLInputType, value: value)
    }
    
    guard value != .undefined else {
        return .undefined
    }
    guard value != .null else {
        return .null
    }

    if let list = type as? GraphQLList {
        let itemType = list.ofType

        if case .array(let value) = value {
            var coercedValues: [Map] = []

            for item in value {
                coercedValues.append(try coerceValue(type: itemType as! GraphQLInputType, value: item))
            }

            return .array(coercedValues)
        }

        return .array([try coerceValue(type: itemType as! GraphQLInputType, value: value)])
    }

    if let objectType = type as? GraphQLInputObjectType {
        guard case .dictionary(let value) = value else {
            throw GraphQLError(message: "Must be dictionary to extract to an input type")
        }

        let fields = objectType.fields

        return try .dictionary(fields.keys.reduce([:]) { obj, fieldName in
            var obj = obj
            let field = fields[fieldName]!
            if let fieldValueMap = value[fieldName] {
                let fieldValue = try coerceValue(
                    type: field.type,
                    value: fieldValueMap
                )
                obj[fieldName] = fieldValue
            } else {
                // If AST doesn't contain field, it is undefined
                if let defaultValue = field.defaultValue {
                    obj[fieldName] = defaultValue
                } else {
                    obj[fieldName] = .undefined
                }
            }
            
            return obj
        })
    }
    
    guard let type = type as? GraphQLLeafType else {
        throw GraphQLError(message: "Must be input type")
    }
    
    let parsed = try type.parseValue(value: value)
    
    guard parsed != .null else {
        return nil
    }

    return parsed
}
