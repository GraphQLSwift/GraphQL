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
            input: inputs[varName]!
        )

        return valuesCopy
    }
}


/**
 * Prepares an object map of argument values given a list of argument
 * definitions and list of argument AST nodes.
 */
func getArgumentValues(argDefs: GraphQLArgumentMap, argASTs: [Argument]?, variableValues: [String: Map] = [:]) throws -> [String: Map] {
    guard let argASTs = argASTs else {
        return [:]
    }

    let argASTMap = argASTs.keyMap({ $0.name.value })

    return try argDefs.reduce([:]) { result, argDef in
        var resultCopy = result
        let name = argDef.value.name
        let valueAST = argASTMap[name]?.value

        var value = try valueFromAST(
            valueAST: valueAST,
            type: argDef.value.type,
            variables: variableValues
        )

        if isNullish(value) {
            value = argDef.value.defaultValue
        }

        if !isNullish(value) {
            resultCopy[name] = value
        }

        return resultCopy
    }
}


/**
 * Given a variable definition, and any value of input, return a value which
 * adheres to the variable definition, or throw an error.
 */
func getVariableValue(schema: GraphQLSchema, definitionAST: VariableDefinition, input: Map) throws -> Map {
    let type = typeFromAST(schema: schema, inputTypeAST: definitionAST.type)
    let variable = definitionAST.variable

    if type != nil || !isInputType(type: type) {
        throw GraphQLError(
            message:
            "Variable \"$\(variable.name.value)\" expected value of type " +
            "\"\(definitionAST.type)\" which cannot be used as an input type.",
            nodes: [definitionAST]
        )
    }

    let inputType = type as! GraphQLInputType
    let errors = try isValidValue(value: input, type: inputType)

    if errors.isEmpty {
        if isNullish(input) {
            if let defaultValue = definitionAST.defaultValue {
                return try valueFromAST(valueAST: defaultValue, type: inputType)!
            }
        }

        return try coerceValue(type: inputType, value: input)!
    }

    if isNullish(input) {
        throw GraphQLError(
            message:
            "Variable \"$\(variable.name.value)\" of required type " +
            "\"\(definitionAST.type)\" was not provided.",
            nodes: [definitionAST]
        )
    }

    let message = !errors.isEmpty ? "\n" + errors.joined(separator: "\n") : ""

    throw GraphQLError(
        message:
        "Variable \"$\(variable.name.value)\" got invalid value " +
        "\(input).\(message)", // TODO: "\(JSON.stringify(input)).\(message)",
        nodes: [definitionAST]
    )
}

/**
 * Given a type and any value, return a runtime value coerced to match the type.
 */
func coerceValue(type: GraphQLInputType, value: Map) throws -> Map? {
    if let nonNull = type as? GraphQLNonNull {
        // Note: we're not checking that the result of coerceValue is non-null.
        // We only call this function after calling isValidValue.
        return try coerceValue(type: nonNull.ofType as! GraphQLInputType, value: value)!
    }

    if isNullish(value) {
        return nil
    }

    if let list = type as? GraphQLList {
        let itemType = list.ofType

        if case .array(let value) = value {
            var coercedValues: [Map] = []

            for item in value {
                coercedValues.append(try coerceValue(type: itemType as! GraphQLInputType, value: item)!)
            }

            return .array(coercedValues)
        }

        return .array([try coerceValue(type: itemType as! GraphQLInputType, value: value)!])
    }

    if let type = type as? GraphQLInputObjectType {
        guard case .dictionary(let value) = value else {
            return nil
        }

        let fields = type.fields

        return try .dictionary(fields.keys.reduce([:]) { obj, fieldName in
            var objCopy = obj
            let field = fields[fieldName]

            var fieldValue = try coerceValue(type: field!.type, value: value[fieldName]!)

            if isNullish(fieldValue) {
                fieldValue = field?.defaultValue
            }

            if !isNullish(fieldValue) {
                objCopy[fieldName] = fieldValue
            }

            return objCopy
        })
    }
    
    guard let type = type as? GraphQLLeafType else {
        fatalError("Must be input type")
    }
    
    let parsed = try type.parseValue(value: value)
    
    if !isNullish(parsed) {
        return parsed
    }

    return nil
}
