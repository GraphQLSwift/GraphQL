import Foundation
import OrderedCollections

/**
 * Prepares an object map of variableValues of the correct type based on the
 * provided variable definitions and arbitrary input. If the input cannot be
 * parsed to match the variable definitions, a GraphQLError will be thrown.
 */
func getVariableValues(
    schema: GraphQLSchema,
    definitionASTs: [VariableDefinition],
    inputs: [String: Map]
) throws -> [String: Map] {
    var vars = [String: Map]()
    for defAST in definitionASTs {
        let varName = defAST.variable.name.value

        let input: Map
        if let nonNilInput = inputs[varName] {
            input = nonNilInput
        } else {
            // If variable is not in inputs it is undefined
            input = .undefined
        }
        vars[varName] = try getVariableValue(
            schema: schema,
            definitionAST: defAST,
            input: input
        )
    }
    return vars
}

/**
 * Prepares an object map of argument values given a list of argument
 * definitions and list of argument AST nodes.
 */
func getArgumentValues(
    argDefs: [GraphQLArgumentDefinition],
    argASTs: [Argument]?,
    variables: [String: Map] = [:]
) throws -> Map {
    guard let argASTs = argASTs else {
        return [:]
    }

    let argASTMap = argASTs.keyMap { $0.name.value }

    var args = OrderedDictionary<String, Map>()
    for argDef in argDefs {
        let argName = argDef.name
        let argValue: Map

        if let argAST = argASTMap[argName] {
            argValue = try valueFromAST(
                valueAST: argAST.value,
                type: argDef.type,
                variables: variables
            )
        } else {
            // If AST doesn't contain field, it is undefined
            if let defaultValue = argDef.defaultValue {
                argValue = defaultValue
            } else {
                argValue = .undefined
            }
        }

        let errors = try validate(value: argValue, forType: argDef.type)
        guard errors.isEmpty else {
            let message = "\n" + errors.joined(separator: "\n")
            throw GraphQLError(
                message:
                "Argument \"\(argName)\" got invalid value \(argValue).\(message)" // TODO: "\(JSON.stringify(input)).\(message)",
            )
        }
        args[argName] = argValue
    }
    return .dictionary(args)
}

/**
 * Given a variable definition, and any value of input, return a value which
 * adheres to the variable definition, or throw an error.
 */
func getVariableValue(
    schema: GraphQLSchema,
    definitionAST: VariableDefinition,
    input: Map
) throws -> Map {
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

    var toCoerce = input
    if input == .undefined, let defaultValue = definitionAST.defaultValue {
        toCoerce = try valueFromAST(valueAST: defaultValue, type: inputType)
    }

    let errors = try validate(value: toCoerce, forType: inputType)
    guard errors.isEmpty else {
        let message = !errors.isEmpty ? "\n" + errors.joined(separator: "\n") : ""
        throw GraphQLError(
            message:
            "Variable \"$\(variable.name.value)\" got invalid value \"\(toCoerce)\".\(message)",
            // TODO: "\(JSON.stringify(input)).\(message)",
            nodes: [definitionAST]
        )
    }

    return try coerceValue(value: toCoerce, type: inputType)
}

/**
 * Given a type and any value, return a runtime value coerced to match the type.
 */
func coerceValue(value: Map, type: GraphQLInputType) throws -> Map {
    if let nonNull = type as? GraphQLNonNull {
        // Note: we're not checking that the result of coerceValue is non-null.
        // We only call this function after calling validate.
        guard let nonNullType = nonNull.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "NonNull must wrap an input type")
        }
        return try coerceValue(value: value, type: nonNullType)
    }

    guard value != .undefined, value != .null else {
        return value
    }

    if let list = type as? GraphQLList {
        guard let itemType = list.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "Input list must wrap an input type")
        }

        if case let .array(value) = value {
            let coercedValues = try value.map { item in
                try coerceValue(value: item, type: itemType)
            }
            return .array(coercedValues)
        }

        // Convert solitary value into single-value array
        return try .array([coerceValue(value: value, type: itemType)])
    }

    if let objectType = type as? GraphQLInputObjectType {
        guard case let .dictionary(value) = value else {
            throw GraphQLError(message: "Must be dictionary to extract to an input type")
        }

        let fields = objectType.fields

        var object = OrderedDictionary<String, Map>()
        for (fieldName, field) in fields {
            if let fieldValueMap = value[fieldName], fieldValueMap != .undefined {
                object[fieldName] = try coerceValue(
                    value: fieldValueMap,
                    type: field.type
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
        return try leafType.parseValue(value: value)
    }

    throw GraphQLError(message: "Provided type is not an input type")
}
