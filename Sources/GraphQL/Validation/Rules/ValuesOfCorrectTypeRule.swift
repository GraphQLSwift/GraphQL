
/**
 * Value literals of correct type
 *
 * A GraphQL document is only valid if all value literals are of the type
 * expected at their position.
 *
 * See https://spec.graphql.org/draft/#sec-Values-of-Correct-Type
 */
func ValuesOfCorrectTypeRule(context: ValidationContext) -> Visitor {
    var variableDefinitions = [String: VariableDefinition]()

    return Visitor(
        enter: { node, _, _, _, _ in
            switch node.kind {
            case .operationDefinition:
                variableDefinitions = [:]
                return .continue
            case .variableDefinition:
                let variableDefinition = node as! VariableDefinition
                variableDefinitions[variableDefinition.variable.name.value] = variableDefinition
                return .continue
            case .listValue:
                let list = node as! ListValue
                guard let type = getNullableType(type: context.parentInputType) else {
                    return .continue
                }
                guard type is GraphQLList else {
                    isValidValueNode(context, list)
                    return .break // Don't traverse further.
                }
                return .continue
            case .objectValue:
                let object = node as! ObjectValue
                let type = getNamedType(type: context.inputType)
                guard let type = type as? GraphQLInputObjectType else {
                    isValidValueNode(context, object)
                    return .break // Don't traverse further.
                }
                // Ensure every required field exists.
                var fieldNodeMap = [String: ObjectField]()
                for field in object.fields {
                    fieldNodeMap[field.name.value] = field
                }
                let fields = (try? type.getFields()) ?? [:]
                for (fieldName, fieldDef) in fields {
                    if fieldNodeMap[fieldName] == nil, isRequiredInputField(fieldDef) {
                        let typeStr = fieldDef.type
                        context.report(
                            error: GraphQLError(
                                message: "Field \"\(type.name).\(fieldDef.name)\" of required type \"\(typeStr)\" was not provided.",
                                nodes: [object]
                            )
                        )
                    }
                }

                if type.isOneOf {
                    validateOneOfInputObject(
                        context: context,
                        node: object,
                        type: type,
                        fieldNodeMap: fieldNodeMap,
                        variableDefinitions: variableDefinitions
                    )
                }
                return .continue
            case .objectField:
                let field = node as! ObjectField
                let parentType = getNamedType(type: context.parentInputType)
                if
                    context.inputType == nil,
                    let parentType = parentType as? GraphQLInputObjectType
                {
                    let parentFields = (try? parentType.getFields()) ?? [:]
                    let suggestions = suggestionList(
                        input: field.name.value,
                        options: Array(parentFields.keys)
                    )
                    context.report(
                        error: GraphQLError(
                            message:
                            "Field \"\(field.name.value)\" is not defined by type \"\(parentType.name)\"." +
                                didYouMean(suggestions: suggestions),
                            nodes: [field]
                        )
                    )
                }
                return .continue
            case .nullValue:
                let null = node as! NullValue
                let type = context.inputType
                if let type = type as? GraphQLNonNull {
                    context.report(
                        error: GraphQLError(
                            message:
                            "Expected value of type \"\(type)\", found \(print(ast: node)).",
                            nodes: [null]
                        )
                    )
                }
                return .continue
            case .enumValue, .intValue, .floatValue, .stringValue, .booleanValue:
                let node = node as! Value
                isValidValueNode(context, node)
                return .continue
            default:
                return .continue
            }
        }
    )
}

/**
 * Any value literal may be a valid representation of a Scalar, depending on
 * that scalar type.
 */
func isValidValueNode(_ context: ValidationContext, _ node: Value) {
    // Report any error at the full type expected by the location.
    guard let locationType = context.inputType else {
        return
    }

    let type = getNamedType(type: locationType)

    if !isLeafType(type: type) {
        context.report(
            error: GraphQLError(
                message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                nodes: [node]
            )
        )
        return
    }

    // Scalars and Enums determine if a literal value is valid via parseLiteral(),
    // which may throw or return an invalid value to indicate failure.
    do {
        if let type = type as? GraphQLScalarType {
            if try type.parseLiteral(valueAST: node) == .undefined {
                context.report(
                    error: GraphQLError(
                        message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                        nodes: [node]
                    )
                )
            }
        }
        if let type = type as? GraphQLEnumType {
            if try type.parseLiteral(valueAST: node) == .undefined {
                context.report(
                    error: GraphQLError(
                        message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                        nodes: [node]
                    )
                )
            }
        }
    } catch {
        if let graphQLError = error as? GraphQLError {
            context.report(error: graphQLError)
        } else {
            context.report(
                error: GraphQLError(
                    message: "Expected value of type \"\(locationType)\", found \(print(ast: node)).",
                    nodes: [node]
                )
            )
        }
    }
}

func validateOneOfInputObject(
    context: ValidationContext,
    node: ObjectValue,
    type: GraphQLInputObjectType,
    fieldNodeMap: [String: ObjectField],
    variableDefinitions: [String: VariableDefinition]
) {
    let keys = Array(fieldNodeMap.keys)
    let isNotExactlyOneField = keys.count != 1

    if isNotExactlyOneField {
        context.report(
            error: GraphQLError(
                message: "OneOf Input Object \"\(type.name)\" must specify exactly one key.",
                nodes: [node]
            )
        )
        return
    }

    let value = fieldNodeMap[keys[0]]?.value
    let isNullLiteral = value == nil || value?.kind == .nullValue

    if isNullLiteral {
        context.report(
            error: GraphQLError(
                message: "Field \"\(type.name).\(keys[0])\" must be non-null.",
                nodes: [node]
            )
        )
        return
    }

    if let value = value, value.kind == .variable {
        let variable = value as! Variable // Force unwrap is safe because of variable definition
        let variableName = variable.name.value

        if
            let definition = variableDefinitions[variableName],
            definition.type.kind != .nonNullType
        {
            context.report(
                error: GraphQLError(
                    message: "Variable \"\(variableName)\" must be non-nullable to be used for OneOf Input Object \"\(type.name)\".",
                    nodes: [node]
                )
            )
            return
        }
    }
}
