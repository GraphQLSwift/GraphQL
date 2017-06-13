/**
 * TypeInfo is a utility class which, given a GraphQL schema, can keep track
 * of the current field and type definitions at any point in a GraphQL document
 * AST during a recursive descent by calling `enter(node: node)` and `leave(node: node)`.
 */
final class TypeInfo {
    let schema: GraphQLSchema;
    var typeStack: [GraphQLOutputType?]
    var parentTypeStack: [GraphQLCompositeType?]
    var inputTypeStack: [GraphQLInputType?]
    var fieldDefStack: [GraphQLFieldDefinition?]
    var directive: GraphQLDirective?
    var argument: GraphQLArgumentDefinition?

    init(schema: GraphQLSchema) {
        self.schema = schema
        self.typeStack = []
        self.parentTypeStack = []
        self.inputTypeStack = []
        self.fieldDefStack = []
        self.directive = nil
        self.argument = nil
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

    var fieldDef: GraphQLFieldDefinition? {
        if !fieldDefStack.isEmpty {
            return fieldDefStack[fieldDefStack.count - 1]
        }
        return nil
    }

    func enter(node: Node) {
        switch node {
        case is SelectionSet:
            let namedType = getNamedType(type: type)
            var compositeType: GraphQLCompositeType? = nil

            if let type = namedType as? GraphQLCompositeType {
                compositeType = type
            }

            parentTypeStack.append(compositeType)

        case let node as Field:
            var fieldDef: GraphQLFieldDefinition? = nil

            if let parentType = self.parentType {
                fieldDef = getFieldDef(schema: schema, parentType: parentType, fieldAST: node)
            }

            fieldDefStack.append(fieldDef)
            typeStack.append(fieldDef?.type)

        case let node as Directive:
            directive = schema.getDirective(name: node.name.value)

        case let node as OperationDefinition:
            var type: GraphQLOutputType? = nil

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
            let typeConditionAST = node.typeCondition
            let outputType = typeConditionAST != nil ? typeFromAST(schema: schema, inputTypeAST: typeConditionAST!) : self.type
            typeStack.append(outputType as? GraphQLOutputType)

        case let node as FragmentDefinition:
            let outputType = typeFromAST(schema: schema, inputTypeAST: node.typeCondition)
            typeStack.append(outputType as? GraphQLOutputType)

        case let node as VariableDefinition:
            let inputType = typeFromAST(schema: schema, inputTypeAST: node.type)
            inputTypeStack.append(inputType as? GraphQLInputType)

        case let node as Argument:
            var argType: GraphQLInputType? = nil

            if let directive = self.directive {
                if let argDef = directive.args.find({ $0.name == node.name.value }) {
                    argType = argDef.type
                    self.argument = argDef
                }
            } else if let fieldDef = self.fieldDef {
                if let argDef = fieldDef.args.find({ $0.name == node.name.value }) {
                    argType = argDef.type
                    self.argument = argDef
                }
            }

            inputTypeStack.append(argType)

        case is ListType: // could be ListValue
            if let listType = getNullableType(type: self.inputType) as? GraphQLList {
                inputTypeStack.append(listType.ofType as? GraphQLInputType)
            }

            inputTypeStack.append(nil)

        case let node as ObjectField:
            if let objectType = getNamedType(type: self.inputType) as? GraphQLInputObjectType {
                let inputField = objectType.fields[node.name.value]
                inputTypeStack.append(inputField?.type)
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
            _ = inputTypeStack.popLast()

        case is ListType /* could be listValue */, is ObjectField:
            _ = inputTypeStack.popLast()

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
func getFieldDef(schema: GraphQLSchema, parentType: GraphQLType, fieldAST: Field) -> GraphQLFieldDefinition? {
    let name = fieldAST.name.value

    if let parentType = parentType as? GraphQLNamedType {
        if name == SchemaMetaFieldDef.name && schema.queryType.name == parentType.name {
            return SchemaMetaFieldDef
        }

        if name == TypeMetaFieldDef.name && schema.queryType.name == parentType.name {
            return TypeMetaFieldDef
        }
    }

    if name == TypeNameMetaFieldDef.name && (parentType is GraphQLObjectType ||
                                             parentType is GraphQLInterfaceType ||
                                             parentType is GraphQLUnionType) {
        return TypeNameMetaFieldDef
    }

    if let parentType = parentType as? GraphQLObjectType {
        return parentType.fields[name]
    }
    
    if let parentType = parentType as? GraphQLInterfaceType {
        return parentType.fields[name]
    }

    return nil
}
