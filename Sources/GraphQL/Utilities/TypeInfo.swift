/**
 * TypeInfo is a utility class which, given a GraphQL schema, can keep track
 * of the current field and type definitions at any point in a GraphQL document
 * AST during a recursive descent by calling `enter(node: node)` and `leave(node: node)`.
 */
final class TypeInfo {
    let schema: GraphQLSchema
    var typeStack: [GraphQLOutputType?]
    var parentTypeStack: [GraphQLCompositeType?]
    var inputTypeStack: [GraphQLInputType?]
    var fieldDefStack: [GraphQLFieldDefinition?]
    var defaultValueStack: [Map]
    var directive: GraphQLDirective?
    var argument: GraphQLArgumentDefinition?
    var enumValue: GraphQLEnumValueDefinition?

    init(schema: GraphQLSchema) {
        self.schema = schema
        typeStack = []
        parentTypeStack = []
        inputTypeStack = []
        fieldDefStack = []
        defaultValueStack = []
        directive = nil
        argument = nil
        enumValue = nil
    }

    var type: GraphQLOutputType? {
        if !typeStack.isEmpty {
            return typeStack[typeStack.count - 1]
        }
        return nil
    }

    var parentType: GraphQLCompositeType? {
        if !parentTypeStack.isEmpty {
            return parentTypeStack[parentTypeStack.count - 1]
        }
        return nil
    }

    var inputType: GraphQLInputType? {
        if !inputTypeStack.isEmpty {
            return inputTypeStack[inputTypeStack.count - 1]
        }
        return nil
    }

    var parentInputType: GraphQLInputType? {
        if inputTypeStack.count >= 2 {
            return inputTypeStack[inputTypeStack.count - 2]
        }
        return nil
    }

    var fieldDef: GraphQLFieldDefinition? {
        if !fieldDefStack.isEmpty {
            return fieldDefStack[fieldDefStack.count - 1]
        }
        return nil
    }

    var defaultValue: Map? {
        if !defaultValueStack.isEmpty {
            return defaultValueStack[defaultValueStack.count - 1]
        }
        return nil
    }

    func enter(node: Node) {
        switch node {
        case is SelectionSet:
            let namedType = getNamedType(type: type)
            var compositeType: GraphQLCompositeType?

            if let type = namedType as? GraphQLCompositeType {
                compositeType = type
            }

            parentTypeStack.append(compositeType)

        case let node as Field:
            var fieldDef: GraphQLFieldDefinition?
            var fieldType: GraphQLType?

            if let parentType = parentType {
                fieldDef = getFieldDef(schema: schema, parentType: parentType, fieldAST: node)
                if let fieldDef = fieldDef {
                    fieldType = fieldDef.type
                }
            }

            fieldDefStack.append(fieldDef)
            typeStack.append(fieldType as? GraphQLOutputType)

        case let node as Directive:
            directive = schema.getDirective(name: node.name.value)

        case let node as OperationDefinition:
            var type: GraphQLOutputType?

            switch node.operation {
            case .query:
                type = schema.queryType
            case .mutation:
                type = schema.mutationType
            case .subscription:
                type = schema.subscriptionType
            }

            typeStack.append(type)

        case let node as InlineFragment:
            let outputType: GraphQLType?
            if let typeConditionAST = node.typeCondition {
                outputType = typeFromAST(schema: schema, inputTypeAST: typeConditionAST)
            } else {
                outputType = getNamedType(type: type)
            }
            typeStack.append(outputType as? GraphQLOutputType)

        case let node as FragmentDefinition:
            let outputType = typeFromAST(schema: schema, inputTypeAST: node.typeCondition)
            typeStack.append(outputType as? GraphQLOutputType)

        case let node as VariableDefinition:
            let inputType = typeFromAST(schema: schema, inputTypeAST: node.type)
            inputTypeStack.append(inputType as? GraphQLInputType)

        case let node as Argument:
            var argDef: GraphQLArgumentDefinition?

            if let directive = directive {
                if let argDefinition = directive.args.find({ $0.name == node.name.value }) {
                    argDef = argDefinition
                }
            } else if let fieldDef = fieldDef {
                if let argDefinition = fieldDef.args.find({ $0.name == node.name.value }) {
                    argDef = argDefinition
                }
            }

            argument = argDef
            defaultValueStack.append(argDef?.defaultValue ?? .undefined)
            inputTypeStack.append(argDef?.type)

        case is ListType, is ListValue:
            let listType = getNullableType(type: inputType)
            let itemType: GraphQLType?

            if let listType = listType as? GraphQLList {
                itemType = listType.ofType
            } else {
                itemType = listType
            }
            defaultValueStack.append(.undefined)

            if let itemType = itemType as? GraphQLInputType {
                inputTypeStack.append(itemType)
            } else {
                inputTypeStack.append(nil)
            }

        case let node as ObjectField:
            let objectType = getNamedType(type: inputType)
            var inputFieldType: GraphQLInputType?
            var inputField: InputObjectFieldDefinition?

            if let objectType = objectType as? GraphQLInputObjectType {
                let inputFields = (try? objectType.getFields()) ?? [:]
                inputField = inputFields[node.name.value]
                if let inputField = inputField {
                    inputFieldType = inputField.type
                }
            }

            defaultValueStack.append(inputField?.defaultValue ?? .undefined)
            inputTypeStack.append(inputFieldType)

        case let node as EnumValue:
            if let enumType = getNamedType(type: inputType) as? GraphQLEnumType {
                enumValue = enumType.nameLookup[node.value]
            } else {
                enumValue = nil
            }

        default:
            break
        }
    }

    func leave(node: Node) {
        switch node {
        case is SelectionSet:
            _ = parentTypeStack.popLast()

        case is Field:
            _ = fieldDefStack.popLast()
            _ = typeStack.popLast()

        case is Directive:
            directive = nil

        case is OperationDefinition, is InlineFragment, is FragmentDefinition:
            _ = typeStack.popLast()

        case is VariableDefinition:
            _ = inputTypeStack.popLast()

        case is Argument:
            argument = nil
            _ = defaultValueStack.popLast()
            _ = inputTypeStack.popLast()

        case is ListType, is ListValue, is ObjectField:
            _ = defaultValueStack.popLast()
            _ = inputTypeStack.popLast()

        case is EnumValue:
            enumValue = nil

        default:
            break
        }
    }
}

/**
 * Not exactly the same as the executor's definition of getFieldDef, in this
 * statically evaluated environment we do not always have an Object type,
 * and need to handle Interface and Union types.
 */
func getFieldDef(
    schema: GraphQLSchema,
    parentType: GraphQLType,
    fieldAST: Field
) -> GraphQLFieldDefinition? {
    let name = fieldAST.name.value

    if let parentType = parentType as? GraphQLNamedType {
        if name == SchemaMetaFieldDef.name, schema.queryType?.name == parentType.name {
            return SchemaMetaFieldDef
        }

        if name == TypeMetaFieldDef.name, schema.queryType?.name == parentType.name {
            return TypeMetaFieldDef
        }
    }

    if
        name == TypeNameMetaFieldDef.name, parentType is GraphQLObjectType ||
        parentType is GraphQLInterfaceType ||
        parentType is GraphQLUnionType
    {
        return TypeNameMetaFieldDef
    }

    if let parentType = parentType as? GraphQLObjectType {
        return try? parentType.getFields()[name]
    }

    if let parentType = parentType as? GraphQLInterfaceType {
        return try? parentType.getFields()[name]
    }

    return nil
}
