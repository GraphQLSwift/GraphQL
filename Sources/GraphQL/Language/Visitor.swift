public struct Descender {
    
    enum Mutation<T: Node> {
        case replace(T)
        case remove
    }
    private let visitor: Visitor
    
    fileprivate var parentStack: [VisitorParent] = []
    private var path: [AnyKeyPath] = []
    private var isBreaking = false
    
    fileprivate mutating func go<H: Node>(node: inout H, key: AnyKeyPath?) -> Mutation<H>? {
        if isBreaking { return nil }
        let parent = parentStack.last
        let newPath: [AnyKeyPath]
        if let key = key {
            newPath = path + [key]
        } else {
            newPath = path
        }
        
        var mutation: Mutation<H>? = nil
        
        switch visitor.enter(node: node, key: key, parent: parent, path: newPath, ancestors: parentStack) {
        case .skip:
            return nil// .node(Optional(result))
        case .continue:
            break
        case let .node(newNode):
            if let newNode = newNode {
                mutation = .replace(newNode)
            } else {
                // TODO: Should we still be traversing the children here?
                mutation = .remove
            }
        case .break:
            isBreaking = true
            return nil
        }
        parentStack.append(.node(node))
        if let key = key {
            path.append(key)
        }
        node.descend(descender: &self)
        if key != nil {
            path.removeLast()
        }
        parentStack.removeLast()
        
        if isBreaking { return mutation }
        
        switch visitor.leave(node: node, key: key, parent: parent, path: newPath, ancestors: parentStack) {
        case .skip, .continue:
            return mutation
        case let .node(newNode):
            if let newNode = newNode {
                return .replace(newNode)
            } else {
                // TODO: Should we still be traversing the children here?
                return .remove
            }
        case .break:
            isBreaking = true
            return mutation
        }
    }
    
    
    mutating func descend<T: Node, U: Node>(_ node: inout T, _ kp: WritableKeyPath<T, U>) {
        switch go(node: &node[keyPath: kp], key: kp) {
        case nil:
            break
        case .replace(let child):
            node[keyPath: kp] = child
        case .remove:
            fatalError("Can't remove this node")
        }
    }
    mutating func descend<T, U: Node>(_ node: inout T, _ kp: WritableKeyPath<T, U?>) {
        guard var oldVal = node[keyPath: kp] else {
            return
        }
        switch go(node: &oldVal, key: kp) {
        case nil:
            node[keyPath: kp] = oldVal
        case .replace(let child):
            node[keyPath: kp] = child
        case .remove:
            node[keyPath: kp] = nil
        }
    }
    mutating func descend<T, U: Node>(_ node: inout T, _ kp: WritableKeyPath<T, [U]>) {
        var toRemove: [Int] = []
        
        parentStack.append(.array(node[keyPath: kp]))
        
        var i = node[keyPath: kp].startIndex
        while i != node[keyPath: kp].endIndex {
            switch go(node: &node[keyPath: kp][i], key: \[U].[i]) {
            case nil:
                break
            case .replace(let child):
                node[keyPath: kp][i] = child
            case .remove:
                toRemove.append(i)
            }
            i = node[keyPath: kp].index(after: i)
        }
        parentStack.removeLast()
        toRemove.forEach { node[keyPath: kp].remove(at: $0) }
    }
    
    mutating func descend<T: Node>(enumCase: inout T) {
        switch go(node: &enumCase, key: nil) {
        case nil:
            break
        case .replace(let node):
            enumCase = node
        case .remove:
            //TODO: figure this out
            fatalError("What happens here?")
        }
    }
    
    fileprivate init(visitor: Visitor) {
        self.visitor = visitor
    }
}


/**
 * visit() will walk through an AST using a depth first traversal, calling
 * the visitor's enter function at each node in the traversal, and calling the
 * leave function after visiting that node and all of its child nodes.
 *
 * By returning different values from the enter and leave functions, the
 * behavior of the visitor can be altered, including skipping over a sub-tree of
 * the AST (by returning `.skip`), editing the AST by returning a value or nil
 * to remove the value, or to stop the whole traversal by returning `.break`.
 *
 * When using visit() to edit an AST, the original AST will not be modified, and
 * a new version of the AST with the changes applied will be returned from the
 * visit function.
 *
 *     struct MyVisitor: Visitor {
 *         func enter(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors:    [VisitorParent]) -> VisitResult<InlineFragment> {
 *             return
 *                 .continue // no action
 *                 .skip // skip visiting this node
 *                 .break // stop visiting altogether
 *                 .node(nil) // delete this node
 *                 .node(newNode) // replace this node with the returned value
 *         }
 *         func leave(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors:    [VisitorParent]) -> VisitResult<InlineFragment> {
 *             return
 *                 .continue // no action
 *                 .skip // skip visiting this node
 *                 .break // stop visiting altogether
 *                 .node(nil) // delete this node
 *                 .node(newNode) // replace this node with the returned value
 *         }
 *     }
 *     let editedAST = visit(ast, visitor: MyVisitor())
 *
 */
@discardableResult
public func visit<T: Node, V: Visitor>(root: T, visitor: V) -> T {
    var descender = Descender(visitor: visitor)
    
    var result = root
    switch descender.go(node: &result, key: nil) {
    case .remove:
        fatalError("Root node in the AST was removed")
    case .replace(let node):
        return node
    case nil:
        return result
    }
}

public enum VisitorParent {
    case node(Node)
    case array([Node])

    public var isNode: Bool {
        if case .node = self {
            return true
        }
        return false
    }

    public var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }
}

public protocol Visitor {
    func enter(name: Name, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Name>
    func leave(name: Name, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Name>

    func enter(document: Document, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Document>
    func leave(document: Document, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Document>
    
    func enter(definition: Definition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Definition>
    func leave(definition: Definition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Definition>
    
    func enter(executableDefinition: ExecutableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ExecutableDefinition>
    func leave(executableDefinition: ExecutableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ExecutableDefinition>

    func enter(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition>
    func leave(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition>

    func enter(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition>
    func leave(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition>

    func enter(variable: Variable, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Variable>
    func leave(variable: Variable, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Variable>

    func enter(selectionSet: SelectionSet, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SelectionSet>
    func leave(selectionSet: SelectionSet, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SelectionSet>
    
    func enter(selection: Selection, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Selection>
    func leave(selection: Selection, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Selection>

    func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field>
    func leave(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field>

    func enter(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument>
    func leave(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument>

    func enter(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread>
    func leave(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread>

    func enter(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InlineFragment>
    func leave(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InlineFragment>

    func enter(fragmentDefinition: FragmentDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentDefinition>
    func leave(fragmentDefinition: FragmentDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentDefinition>
    
    func enter(value: Value, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Value>
    func leave(value: Value, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Value>

    func enter(intValue: IntValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<IntValue>
    func leave(intValue: IntValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<IntValue>

    func enter(floatValue: FloatValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FloatValue>
    func leave(floatValue: FloatValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FloatValue>

    func enter(stringValue: StringValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<StringValue>
    func leave(stringValue: StringValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<StringValue>

    func enter(booleanValue: BooleanValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<BooleanValue>
    func leave(booleanValue: BooleanValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<BooleanValue>
    
    func enter(nullValue: NullValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NullValue>
    func leave(nullValue: NullValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NullValue>

    func enter(enumValue: EnumValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValue>
    func leave(enumValue: EnumValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValue>

    func enter(listValue: ListValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListValue>
    func leave(listValue: ListValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListValue>

    func enter(objectValue: ObjectValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectValue>
    func leave(objectValue: ObjectValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectValue>

    func enter(objectField: ObjectField, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectField>
    func leave(objectField: ObjectField, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectField>

    func enter(directive: Directive, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Directive>
    func leave(directive: Directive, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Directive>

    func enter(namedType: NamedType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NamedType>
    func leave(namedType: NamedType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NamedType>

    func enter(listType: ListType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListType>
    func leave(listType: ListType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListType>

    func enter(nonNullType: NonNullType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NonNullType>
    func leave(nonNullType: NonNullType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NonNullType>

    func enter(schemaDefinition: SchemaDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SchemaDefinition>
    func leave(schemaDefinition: SchemaDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SchemaDefinition>

    func enter(operationTypeDefinition: OperationTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationTypeDefinition>
    func leave(operationTypeDefinition: OperationTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationTypeDefinition>

    func enter(scalarTypeDefinition: ScalarTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ScalarTypeDefinition>
    func leave(scalarTypeDefinition: ScalarTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ScalarTypeDefinition>

    func enter(objectTypeDefinition: ObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectTypeDefinition>
    func leave(objectTypeDefinition: ObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectTypeDefinition>

    func enter(fieldDefinition: FieldDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FieldDefinition>
    func leave(fieldDefinition: FieldDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FieldDefinition>

    func enter(inputValueDefinition: InputValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputValueDefinition>
    func leave(inputValueDefinition: InputValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputValueDefinition>

    func enter(interfaceTypeDefinition: InterfaceTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InterfaceTypeDefinition>
    func leave(interfaceTypeDefinition: InterfaceTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InterfaceTypeDefinition>

    func enter(unionTypeDefinition: UnionTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<UnionTypeDefinition>
    func leave(unionTypeDefinition: UnionTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<UnionTypeDefinition>

    func enter(enumTypeDefinition: EnumTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumTypeDefinition>
    func leave(enumTypeDefinition: EnumTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumTypeDefinition>

    func enter(enumValueDefinition: EnumValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValueDefinition>
    func leave(enumValueDefinition: EnumValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValueDefinition>

    func enter(inputObjectTypeDefinition: InputObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputObjectTypeDefinition>
    func leave(inputObjectTypeDefinition: InputObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputObjectTypeDefinition>

    func enter(typeExtensionDefinition: TypeExtensionDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<TypeExtensionDefinition>
    func leave(typeExtensionDefinition: TypeExtensionDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<TypeExtensionDefinition>

    func enter(directiveDefinition: DirectiveDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<DirectiveDefinition>
    func leave(directiveDefinition: DirectiveDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<DirectiveDefinition>
    
    func enter<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T>
    func leave<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T>
}

public extension Visitor {
    func enter(name: Name, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Name> { .continue }
    func leave(name: Name, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Name> { .continue }
    
    func enter(document: Document, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Document> { .continue }
    func leave(document: Document, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Document> { .continue }
    
    func enter(definition: Definition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Definition> { .continue }
    func leave(definition: Definition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Definition> { .continue }
    
    func enter(executableDefinition: ExecutableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ExecutableDefinition> { .continue }
    func leave(executableDefinition: ExecutableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ExecutableDefinition> { .continue }
    
    func enter(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition> { .continue }
    func leave(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition> { .continue }

    func enter(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition> { .continue }
    func leave(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition> { .continue }

    func enter(variable: Variable, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Variable> { .continue }
    func leave(variable: Variable, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Variable> { .continue }

    func enter(selectionSet: SelectionSet, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SelectionSet> { .continue }
    func leave(selectionSet: SelectionSet, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SelectionSet> { .continue }
    
    func enter(selection: Selection, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Selection> { .continue }
    func leave(selection: Selection, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Selection> { .continue }

    func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> { .continue }
    func leave(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> { .continue }
    
    func enter(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument> { .continue }
    func leave(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument> { .continue }

    func enter(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread> { .continue }
    func leave(fragmentSpread: FragmentSpread, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentSpread> { .continue }

    func enter(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InlineFragment> { .continue }
    func leave(inlineFragment: InlineFragment, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InlineFragment> { .continue }

    func enter(fragmentDefinition: FragmentDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentDefinition> { .continue }
    func leave(fragmentDefinition: FragmentDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FragmentDefinition> { .continue }
    
    func enter(value: Value, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Value> { .continue }
    func leave(value: Value, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Value> { .continue }

    func enter(intValue: IntValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<IntValue> { .continue }
    func leave(intValue: IntValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<IntValue> { .continue }

    func enter(floatValue: FloatValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FloatValue> { .continue }
    func leave(floatValue: FloatValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FloatValue> { .continue }

    func enter(stringValue: StringValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<StringValue> { .continue }
    func leave(stringValue: StringValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<StringValue> { .continue }

    func enter(booleanValue: BooleanValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<BooleanValue> { .continue }
    func leave(booleanValue: BooleanValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<BooleanValue> { .continue }
    
    func enter(nullValue: NullValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NullValue> { .continue }
    func leave(nullValue: NullValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NullValue> { .continue }

    func enter(enumValue: EnumValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValue> { .continue }
    func leave(enumValue: EnumValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValue> { .continue }

    func enter(listValue: ListValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListValue> { .continue }
    func leave(listValue: ListValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListValue> { .continue }

    func enter(objectValue: ObjectValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectValue> { .continue }
    func leave(objectValue: ObjectValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectValue> { .continue }

    func enter(objectField: ObjectField, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectField> { .continue }
    func leave(objectField: ObjectField, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectField> { .continue }

    func enter(directive: Directive, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Directive> { .continue }
    func leave(directive: Directive, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Directive> { .continue }

    func enter(type: Type, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Type> { .continue }
    func leave(type: Type, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Type> { .continue }
    
    func enter(namedType: NamedType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NamedType> { .continue }
    func leave(namedType: NamedType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NamedType> { .continue }

    func enter(listType: ListType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListType> { .continue }
    func leave(listType: ListType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ListType> { .continue }

    func enter(nonNullType: NonNullType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NonNullType> { .continue }
    func leave(nonNullType: NonNullType, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<NonNullType> { .continue }

    func enter(schemaDefinition: SchemaDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SchemaDefinition> { .continue }
    func leave(schemaDefinition: SchemaDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<SchemaDefinition> { .continue }

    func enter(operationTypeDefinition: OperationTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationTypeDefinition> { .continue }
    func leave(operationTypeDefinition: OperationTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationTypeDefinition> { .continue }

    func enter(scalarTypeDefinition: ScalarTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ScalarTypeDefinition> { .continue }
    func leave(scalarTypeDefinition: ScalarTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ScalarTypeDefinition> { .continue }

    func enter(objectTypeDefinition: ObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectTypeDefinition> { .continue }
    func leave(objectTypeDefinition: ObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<ObjectTypeDefinition> { .continue }

    func enter(fieldDefinition: FieldDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FieldDefinition> { .continue }
    func leave(fieldDefinition: FieldDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<FieldDefinition> { .continue }

    func enter(inputValueDefinition: InputValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputValueDefinition> { .continue }
    func leave(inputValueDefinition: InputValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputValueDefinition> { .continue }

    func enter(interfaceTypeDefinition: InterfaceTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InterfaceTypeDefinition> { .continue }
    func leave(interfaceTypeDefinition: InterfaceTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InterfaceTypeDefinition> { .continue }

    func enter(unionTypeDefinition: UnionTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<UnionTypeDefinition> { .continue }
    func leave(unionTypeDefinition: UnionTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<UnionTypeDefinition> { .continue }

    func enter(enumTypeDefinition: EnumTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumTypeDefinition> { .continue }
    func leave(enumTypeDefinition: EnumTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumTypeDefinition> { .continue }

    func enter(enumValueDefinition: EnumValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValueDefinition> { .continue }
    func leave(enumValueDefinition: EnumValueDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<EnumValueDefinition> { .continue }

    func enter(inputObjectTypeDefinition: InputObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputObjectTypeDefinition> { .continue }
    func leave(inputObjectTypeDefinition: InputObjectTypeDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<InputObjectTypeDefinition> { .continue }

    func enter(typeExtensionDefinition: TypeExtensionDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<TypeExtensionDefinition> { .continue }
    func leave(typeExtensionDefinition: TypeExtensionDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<TypeExtensionDefinition> { .continue }

    func enter(directiveDefinition: DirectiveDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<DirectiveDefinition> { .continue }
    func leave(directiveDefinition: DirectiveDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<DirectiveDefinition> { .continue }
    
    func enter<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        switch node {
        case let name as Name:
            return enter(name: name, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let document as Document:
            return enter(document: document, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let definition as Definition:
            return enter(definition: definition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let executableDefinition as ExecutableDefinition:
            return enter(executableDefinition: executableDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let operationDefinition as OperationDefinition:
            return enter(operationDefinition: operationDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let variableDefinition as VariableDefinition:
            return enter(variableDefinition: variableDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let variable as Variable:
            return enter(variable: variable, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let selectionSet as SelectionSet:
            return enter(selectionSet: selectionSet, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let selection as Selection:
            return enter(selection: selection, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let field as Field:
            return enter(field: field, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let argument as Argument:
            return enter(argument: argument, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fragmentSpread as FragmentSpread:
            return enter(fragmentSpread: fragmentSpread, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inlineFragment as InlineFragment:
            return enter(inlineFragment: inlineFragment, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fragmentDefinition as FragmentDefinition:
            return enter(fragmentDefinition: fragmentDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let value as Value:
            return enter(value: value, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let intValue as IntValue:
            return enter(intValue: intValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let floatValue as FloatValue:
            return enter(floatValue: floatValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let stringValue as StringValue:
            return enter(stringValue: stringValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let booleanValue as BooleanValue:
            return enter(booleanValue: booleanValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let nullValue as NullValue:
            return enter(nullValue: nullValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumValue as EnumValue:
            return enter(enumValue: enumValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let listValue as ListValue:
            return enter(listValue: listValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectValue as ObjectValue:
            return enter(objectValue: objectValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectField as ObjectField:
            return enter(objectField: objectField, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let directive as Directive:
            return enter(directive: directive, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let type as Type:
            return enter(type: type, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let namedType as NamedType:
            return enter(namedType: namedType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let listType as ListType:
            return enter(listType: listType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let nonNullType as NonNullType:
            return enter(nonNullType: nonNullType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let schemaDefinition as SchemaDefinition:
            return enter(schemaDefinition: schemaDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let operationTypeDefinition as OperationTypeDefinition:
            return enter(operationTypeDefinition: operationTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let scalarTypeDefinition as ScalarTypeDefinition:
            return enter(scalarTypeDefinition: scalarTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectTypeDefinition as ObjectTypeDefinition:
            return enter(objectTypeDefinition: objectTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fieldDefinition as FieldDefinition:
            return enter(fieldDefinition: fieldDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inputValueDefinition as InputValueDefinition:
            return enter(inputValueDefinition: inputValueDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let interfaceTypeDefinition as InterfaceTypeDefinition:
            return enter(interfaceTypeDefinition: interfaceTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let unionTypeDefinition as UnionTypeDefinition:
            return enter(unionTypeDefinition: unionTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumTypeDefinition as EnumTypeDefinition:
            return enter(enumTypeDefinition: enumTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumValueDefinition as EnumValueDefinition:
            return enter(enumValueDefinition: enumValueDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inputObjectTypeDefinition as InputObjectTypeDefinition:
            return enter(inputObjectTypeDefinition: inputObjectTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let typeExtensionDefinition as TypeExtensionDefinition:
            return enter(typeExtensionDefinition: typeExtensionDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let directiveDefinition as DirectiveDefinition:
            return enter(directiveDefinition: directiveDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        default:
            fatalError()
        }
    }

    func leave<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        switch node {
        case let name as Name:
            return leave(name: name, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let document as Document:
            return leave(document: document, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let definition as Definition:
            return leave(definition: definition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let executableDefinition as ExecutableDefinition:
            return leave(executableDefinition: executableDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let operationDefinition as OperationDefinition:
            return leave(operationDefinition: operationDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let variableDefinition as VariableDefinition:
            return leave(variableDefinition: variableDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let variable as Variable:
            return leave(variable: variable, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let selectionSet as SelectionSet:
            return leave(selectionSet: selectionSet, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let selection as Selection:
            return leave(selection: selection, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let field as Field:
            return leave(field: field, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let argument as Argument:
            return leave(argument: argument, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fragmentSpread as FragmentSpread:
            return leave(fragmentSpread: fragmentSpread, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inlineFragment as InlineFragment:
            return leave(inlineFragment: inlineFragment, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fragmentDefinition as FragmentDefinition:
            return leave(fragmentDefinition: fragmentDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let value as Value:
            return leave(value: value, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let intValue as IntValue:
            return leave(intValue: intValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let floatValue as FloatValue:
            return leave(floatValue: floatValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let stringValue as StringValue:
            return leave(stringValue: stringValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let booleanValue as BooleanValue:
            return leave(booleanValue: booleanValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let nullValue as NullValue:
            return leave(nullValue: nullValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumValue as EnumValue:
            return leave(enumValue: enumValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let listValue as ListValue:
            return leave(listValue: listValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectValue as ObjectValue:
            return leave(objectValue: objectValue, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectField as ObjectField:
            return leave(objectField: objectField, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let directive as Directive:
            return leave(directive: directive, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let type as Type:
            return leave(type: type, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let namedType as NamedType:
            return leave(namedType: namedType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let listType as ListType:
            return leave(listType: listType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let nonNullType as NonNullType:
            return leave(nonNullType: nonNullType, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let schemaDefinition as SchemaDefinition:
            return leave(schemaDefinition: schemaDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let operationTypeDefinition as OperationTypeDefinition:
            return leave(operationTypeDefinition: operationTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let scalarTypeDefinition as ScalarTypeDefinition:
            return leave(scalarTypeDefinition: scalarTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let objectTypeDefinition as ObjectTypeDefinition:
            return leave(objectTypeDefinition: objectTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let fieldDefinition as FieldDefinition:
            return leave(fieldDefinition: fieldDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inputValueDefinition as InputValueDefinition:
            return leave(inputValueDefinition: inputValueDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let interfaceTypeDefinition as InterfaceTypeDefinition:
            return leave(interfaceTypeDefinition: interfaceTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let unionTypeDefinition as UnionTypeDefinition:
            return leave(unionTypeDefinition: unionTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumTypeDefinition as EnumTypeDefinition:
            return leave(enumTypeDefinition: enumTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let enumValueDefinition as EnumValueDefinition:
            return leave(enumValueDefinition: enumValueDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let inputObjectTypeDefinition as InputObjectTypeDefinition:
            return leave(inputObjectTypeDefinition: inputObjectTypeDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let typeExtensionDefinition as TypeExtensionDefinition:
            return leave(typeExtensionDefinition: typeExtensionDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        case let directiveDefinition as DirectiveDefinition:
            return leave(directiveDefinition: directiveDefinition, key: key, parent: parent, ancestors: ancestors) as! VisitResult<T>
        default:
            fatalError()
        }
    }
}

/**
 * A visitor which maintains a provided TypeInfo instance alongside another visitor.
 */
public struct VisitorWithTypeInfo: Visitor {
    let visitor: Visitor
    let typeInfo: TypeInfo
    public init(visitor: Visitor, typeInfo: TypeInfo) {
        self.visitor = visitor
        self.typeInfo = typeInfo
    }
    public func enter<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        typeInfo.enter(node: node)

        let result = visitor.enter(
            node: node,
            key: key,
            parent: parent,
            path: path,
            ancestors: ancestors
        )
        
        if case .continue = result {} else {
            typeInfo.leave(node: node)

            if case .node(let node) = result, let n = node {
                typeInfo.enter(node: n)
            }
            
        }
        return result
    }
    public func leave<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        let result = visitor.leave(
            node: node,
            key: key,
            parent: parent,
            path: path,
            ancestors: ancestors
        )
        
        typeInfo.leave(node: node)
        return result
    }
}

/**
 A visitor which visits delegates to many visitors to run in parallel.
 
 Each visitor will be visited for each node before moving on.
 If a prior visitor edits a node, no following visitors will see that node.
 */
class ParallelVisitor: Visitor {
    let visitors: [Visitor]
    
    private var skipping: [SkipStatus]
    private enum SkipStatus {
        case skipping([AnyKeyPath])
        case breaking
        case continuing
    }
    
    init(visitors: [Visitor]) {
        self.visitors = visitors
        self.skipping = [SkipStatus](repeating: .continuing, count: visitors.count)
    }
    
    public func enter<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        for (i, visitor) in visitors.enumerated() {
            guard case .continuing = skipping[i] else {
                continue
            }
            let result = visitor.enter(
                node: node,
                key: key,
                parent: parent,
                path: path,
                ancestors: ancestors
            )
            switch result {
            case .node:
                return result
            case .break:
                skipping[i] = .breaking
            case .skip:
                skipping[i] = .skipping(path)
            case .continue:
                break
            }
        }
        return .continue
    }
    public func leave<T: Node>(node: T, key: AnyKeyPath?, parent: VisitorParent?, path: [AnyKeyPath], ancestors: [VisitorParent]) -> VisitResult<T> {
        for (i, visitor) in visitors.enumerated() {
            switch skipping[i] {
            case .skipping(path):
                // We've come back to leave the node we were skipping
                // So unset the skipping status so that the visitor will resume traversing
                skipping[i] = .continuing
            case .skipping, .breaking:
                break
            case .continuing:
                let result = visitor.leave(
                    node: node,
                    key: key,
                    parent: parent,
                    path: path,
                    ancestors: ancestors
                )
                switch result {
                case .break:
                    skipping[i] = .breaking
                case .node:
                    return result
                default:
                    break
                }
            }
        }
        return .continue
    }
}

public enum VisitResult<T: Node> {
    case `continue`, skip, `break`, node(T?)
}

fileprivate enum SomeVisitResult2 {
    case `continue`, skip, `break`, node(Node?)
    static func from<T: Node>(_ visitResult: VisitResult<T>) -> SomeVisitResult2 {
        switch visitResult {
        case .continue:
            return .continue
        case .skip:
            return .skip
        case .break:
            return .break
        case .node(let node):
            return .node(node)
        }
    }
}

/**
 * Creates a new visitor instance which maintains a provided TypeInfo instance
 * along with visiting visitor.
 */

/**
 * Creates a new visitor instance which maintains a provided TypeInfo instance
 * along with visiting visitor.
 */
