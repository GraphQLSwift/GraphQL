/**
 * Contains a range of UTF-8 character offsets and token references that
 * identify the region of the source from which the AST derived.
 */
public struct Location {

    /**
     * The character offset at which this Node begins.
     */
    let start: Int

    /**
     * The character offset at which this Node ends.
     */
    let end: Int

    /**
     * The Token at which this Node begins.
     */
    let startToken: Token

    /**
     * The Token at which this Node ends.
     */
    let endToken: Token

    /**
     * The Source document the AST represents.
     */
    let source: Source
}

/**
 * Represents a range of characters represented by a lexical token
 * within a Source.
 */
final class Token {
    enum Kind : String, CustomStringConvertible {
        case sof = "<SOF>"
        case eof = "<EOF>"
        case bang = "!"
        case dollar = "$"
        case openingParenthesis = "("
        case closingParenthesis = ")"
        case spread = "..."
        case colon = ":"
        case equals = "="
        case at = "@"
        case openingBracket = "["
        case closingBracket = "]"
        case openingBrace = "{"
        case pipe = "|"
        case closingBrace = "}"
        case name = "Name"
        case int = "Int"
        case float = "Float"
        case string = "String"
        case comment = "Comment"

        var description: String {
            return rawValue
        }
    }

    /**
     * The kind of Token.
     */
    let kind: Kind

    /**
     * The character offset at which this Node begins.
     */
    let start: Int
    /**
     * The character offset at which this Node ends.
     */
    let end: Int
    /**
     * The 1-indexed line number on which this Token appears.
     */
    let line: Int
    /**
     * The 1-indexed column number at which this Token begins.
     */
    let column: Int
    /**
     * For non-punctuation tokens, represents the interpreted value of the token.
     */
    let value: String?
    /**
     * Tokens exist as nodes in a double-linked-list amongst all tokens
     * including ignored tokens. <SOF> is always the first node and <EOF>
     * the last.
     */
    let prev: Token?
    var next: Token?

    init(kind: Kind, start: Int, end: Int, line: Int, column: Int, value: String? = nil, prev: Token? = nil, next: Token? = nil) {
        self.kind = kind
        self.start = start
        self.end = end
        self.line = line
        self.column = column
        self.value = value
        self.prev = prev
        self.next = next
    }
}

extension Token : Equatable {}

func == (lhs: Token, rhs: Token) -> Bool {
    return lhs.kind   == rhs.kind   &&
           lhs.start  == rhs.start  &&
           lhs.end    == rhs.end    &&
           lhs.line   == rhs.line   &&
           lhs.column == rhs.column &&
           lhs.value  == rhs.value
}

extension Token : CustomStringConvertible {
    var description: String {
        var description = "Token(kind: \(kind)"

        if let value = value {
            description += ", value: \(value)"
        }

        description += ", line: \(line), column: \(column))"

        return description
    }
}

public enum NodeResult {
    case node(Node)
    case array([Node])

    var isNode: Bool {
        if case .node = self {
            return true
        }
        return false
    }

    var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }
}

/**
 * The list of all possible AST node types.
 */
public protocol Node {
    var kind: Kind { get }
    var loc: Location? { get }
    func get(key: IndexPathElement) -> NodeResult?
    func set(value: Node?, key: IndexPathElement)
    var key: String { get }
}

extension Node {
    public var key: String {
        return ""
    }

    public func get(key: IndexPathElement) -> NodeResult? {
        return nil
    }

    public func set(value: Node?, key: IndexPathElement) {

    }
}
//= Name
//    | Document
//    | OperationDefinition
//    | VariableDefinition
//    | Variable
//    | SelectionSet
//    | Field
//    | Argument
//    | FragmentSpread
//    | InlineFragment
//    | FragmentDefinition
//    | IntValue
//    | FloatValue
//    | StringValue
//    | BooleanValue
//    | EnumValue
//    | ListValue
//    | ObjectValue
//    | ObjectField
//    | Directive
//    | NamedType
//    | ListType
//    | NonNullType
//    | SchemaDefinition
//    | OperationTypeDefinition
//    | ScalarTypeDefinition
//    | ObjectTypeDefinition
//    | FieldDefinition
//    | InputValueDefinition
//    | InterfaceTypeDefinition
//    | UnionTypeDefinition
//    | EnumTypeDefinition
//    | EnumValueDefinition
//    | InputObjectTypeDefinition
//    | TypeExtensionDefinition
//    | DirectiveDefinition

// Name
final class Name : Node, Equatable {
    let kind: Kind = .name
    let loc: Location?
    let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: Name, rhs: Name) -> Bool {
    return lhs.value == rhs.value
}

// Document
final class Document : Node, Equatable {
    let kind: Kind = .document
    let loc: Location?
    let definitions: [Definition]

    init(loc: Location? = nil, definitions: [Definition]) {
        self.loc = loc
        self.definitions = definitions
    }

    func get(key: IndexPathElement) -> NodeResult? {
        switch key.indexPathValue {
        case .key(let key):
            switch key {
            case "definitions":
                guard !definitions.isEmpty else {
                    return nil
                }
                return .array(definitions)
            default:
                return nil
            }
        case .index(let index):
            return .node(definitions[index])
        }
    }
}

func == (lhs: Document, rhs: Document) -> Bool {
    guard lhs.definitions.count == rhs.definitions.count else {
        return false
    }

    for (l, r) in zip(lhs.definitions, rhs.definitions) {
        guard l == r else {
            return false
        }
    }

    return true
}

protocol Definition : Node {}
//= OperationDefinition
//    | FragmentDefinition
//    | TypeSystemDefinition // experimental non-spec addition.

func == (lhs: Definition, rhs: Definition) -> Bool {
    switch lhs {
    case let l as OperationDefinition:
        if let r = rhs as? OperationDefinition {
            return l == r
        }
    case let l as FragmentDefinition:
        if let r = rhs as? FragmentDefinition {
            return l == r
        }
    case let l as TypeSystemDefinition:
        if let r = rhs as? TypeSystemDefinition {
            return false // l == r
        }
    default:
        return false
    }

    return false
}


// Note: subscription is an experimental non-spec addition.
enum OperationType : String {
    case query = "query"
    case mutation = "mutation"
    case subscription = "subscription"
}

public final class OperationDefinition : Node, Definition, Hashable, Equatable {
    public let kind: Kind = .operationDefinition
    public let loc: Location?
    let operation: OperationType
    let name: Name?
    let variableDefinitions: [VariableDefinition]
    let directives: [Directive]
    let selectionSet: SelectionSet

    init(loc: Location? = nil, operation: OperationType, name: Name? = nil, variableDefinitions: [VariableDefinition] = [], directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.operation = operation
        self.name = name
        self.variableDefinitions = variableDefinitions
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public var key: String {
        return "operation"
    }

    public func get(key: IndexPathElement) -> NodeResult? {
        switch key.indexPathValue {
        case .key(let key):
            switch key {
            case "name":
                return name.map({ .node($0) })
            case "variableDefinitions":
                guard !variableDefinitions.isEmpty else {
                    return nil
                }
                return .array(variableDefinitions)
            case "directives":
                guard !variableDefinitions.isEmpty else {
                    return nil
                }
                return .array(directives)
            case "selectionSet":
                return .node(selectionSet)
            default:
                return nil
            }
        case .index:
            return nil
        }
    }
}

extension OperationDefinition {
    public var hashValue: Int {
        // TODO: use uuid
        return 0
    }
}

public func == (lhs: OperationDefinition, rhs: OperationDefinition) -> Bool {
    return lhs.operation == rhs.operation &&
           lhs.name == rhs.name &&
           lhs.variableDefinitions == rhs.variableDefinitions &&
           lhs.directives == rhs.directives &&
           lhs.selectionSet == rhs.selectionSet
}

public final class VariableDefinition : Node, Equatable {
    public let kind: Kind = .variableDefinition
    public let loc: Location?
    let variable: Variable
    let type: Type
    let defaultValue: Value?

    init(loc: Location? = nil, variable: Variable, type: Type, defaultValue: Value? = nil) {
        self.loc = loc
        self.variable = variable
        self.type = type
        self.defaultValue = defaultValue
    }

    public func get(key: IndexPathElement) -> NodeResult? {
        switch key.indexPathValue {
        case .key(let key):
            switch key {
            case "variable":
                return .node(variable)
            case "type":
                return .node(type)
            case "defaultValue":
                return defaultValue.map({ .node($0) })
            default:
                return nil
            }
        case .index:
            return nil
        }
    }
}

public func == (lhs: VariableDefinition, rhs: VariableDefinition) -> Bool {
    guard lhs.variable == rhs.variable else {
        return false
    }

    guard lhs.type == rhs.type else {
        return false
    }

    if lhs.defaultValue == nil && rhs.defaultValue == nil {
        return true
    }

    guard let l = lhs.defaultValue, let r = rhs.defaultValue else {
        return false
    }

    return l == r
}

public final class Variable : Node, Value, Equatable {
    public let kind: Kind = .variable
    public let loc: Location?
    let name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }
}

public func == (lhs: Variable, rhs: Variable) -> Bool {
    return lhs.name == rhs.name
}

public final class SelectionSet : Node, Hashable, Equatable {
    public let kind: Kind = .selectionSet
    public let loc: Location?
    let selections: [Selection]

    init(loc: Location? = nil, selections: [Selection]) {
        self.loc = loc
        self.selections = selections
    }

    public func get(key: IndexPathElement) -> NodeResult? {
        switch key.indexPathValue {
        case .key(let key):
            switch key {
            case "selections":
                guard !selections.isEmpty else {
                    return nil
                }
                return .array(selections)
            default:
                return nil
            }
        case .index(let index):
            return .node(selections[index])
        }
    }
}

extension SelectionSet {
    public var hashValue: Int {
        // TODO: use uuid or location
        return 0
    }
}

public func == (lhs: SelectionSet, rhs: SelectionSet) -> Bool {
    guard lhs.selections.count == rhs.selections.count else {
        return false
    }

    for (l, r) in zip(lhs.selections, rhs.selections) {
        guard l == r else {
            return false
        }
    }

    return true
}

protocol Selection : Node {}
//= Field
//    | FragmentSpread
//    | InlineFragment

func == (lhs: Selection, rhs: Selection) -> Bool {
    switch lhs {
    case let l as Field:
        if let r = rhs as? Field {
            return l == r
        }
    case let l as FragmentSpread:
        if let r = rhs as? FragmentSpread {
            return l == r
        }
    case let l as InlineFragment:
        if let r = rhs as? InlineFragment {
            return l == r
        }
    default:
        return false
    }

    return false
}

final class Field : Node, Selection, Equatable {
    let kind: Kind = .field
    let loc: Location?
    let alias: Name?
    let name: Name
    let arguments: [Argument]
    let directives: [Directive]
    let selectionSet: SelectionSet?

    init(loc: Location? = nil, alias: Name? = nil, name: Name, arguments: [Argument] = [], directives: [Directive] = [], selectionSet: SelectionSet? = nil) {
        self.loc = loc
        self.alias = alias
        self.name = name
        self.arguments = arguments
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public func get(key: IndexPathElement) -> NodeResult? {
        switch key.indexPathValue {
        case .key(let key):
            switch key {
            case "alias":
                return alias.map({ .node($0) })
            case "name":
                return .node(name)
            case "arguments":
                guard !arguments.isEmpty else {
                    return nil
                }
                return .array(arguments)
            case "directives":
                guard !directives.isEmpty else {
                    return nil
                }
                return .array(directives)
            case "selectionSet":
                return selectionSet.map({ .node($0) })
            default:
                return nil
            }
        case .index:
            return nil
        }
    }
}

func == (lhs: Field, rhs: Field) -> Bool {
    return lhs.alias == rhs.alias &&
           lhs.name == rhs.name &&
           lhs.arguments == rhs.arguments &&
           lhs.directives == rhs.directives &&
           lhs.selectionSet == rhs.selectionSet
}

final class Argument : Node, Equatable {
    let kind: Kind = .argument
    let loc: Location?
    let name: Name
    let value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }
}

func == (lhs: Argument, rhs: Argument) -> Bool {
    return lhs.name == rhs.name &&
           lhs.value == rhs.value
}

protocol Fragment : Selection {}

// Fragments
final class FragmentSpread : Node, Selection, Fragment {
    let kind: Kind = .fragmentSpread
    let loc: Location?
    let name: Name
    let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }
}

protocol HasTypeCondition {
    func getTypeCondition() -> NamedType?
}

final class InlineFragment : Node, Selection, Fragment, HasTypeCondition {
    let kind: Kind = .inlineFragment
    let loc: Location?
    let typeCondition: NamedType?
    let directives: [Directive]
    let selectionSet: SelectionSet

    init(loc: Location? = nil, typeCondition: NamedType? = nil, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }

    func getTypeCondition() -> NamedType? {
        return typeCondition
    }
}

public final class FragmentDefinition : Node, Hashable, Definition, HasTypeCondition {
    public let kind: Kind = .fragmentDefinition
    public let loc: Location?
    let name: Name
    let typeCondition: NamedType
    let directives: [Directive]
    let selectionSet: SelectionSet

    init(loc: Location? = nil, name: Name, typeCondition: NamedType, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.name = name
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }

    func getTypeCondition() -> NamedType? {
        return typeCondition
    }
}

extension FragmentDefinition {
    public var hashValue: Int {
        // TODO: use uuid
        return 0
    }
}

public func == (lhs: FragmentDefinition, rhs: FragmentDefinition) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

// Values
public protocol Value : Node {}
//= Variable
//    | IntValue
//    | FloatValue
//    | StringValue
//    | BooleanValue
//    | EnumValue
//    | ListValue
//    | ObjectValue

public func == (lhs: Value, rhs: Value) -> Bool {
    switch lhs {
    case let l as Variable:
        if let r = rhs as? Variable {
            return l == r
        }
    case let l as IntValue:
        if let r = rhs as? IntValue {
            return l == r
        }
    case let l as FloatValue:
        if let r = rhs as? FloatValue {
            return l == r
        }
    case let l as StringValue:
        if let r = rhs as? StringValue {
            return l == r
        }
    case let l as BooleanValue:
        if let r = rhs as? BooleanValue {
            return l == r
        }
    case let l as EnumValue:
        if let r = rhs as? EnumValue {
            return l == r
        }
    case let l as ListValue:
        if let r = rhs as? ListValue {
            return l == r
        }
    case let l as ObjectValue:
        if let r = rhs as? ObjectValue {
            return l == r
        }
    default:
        return false
    }

    return false
}

final class IntValue : Node, Value, Equatable {
    let kind: Kind = .intValue
    let loc: Location?
    let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: IntValue, rhs: IntValue) -> Bool {
    return lhs.value == rhs.value
}

final class FloatValue : Node, Value, Equatable {
    let kind: Kind = .floatValue
    let loc: Location?
    let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: FloatValue, rhs: FloatValue) -> Bool {
    return lhs.value == rhs.value
}

final class StringValue : Node, Value, Equatable {
    let kind: Kind = .stringValue
    let loc: Location?
    let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: StringValue, rhs: StringValue) -> Bool {
    return lhs.value == rhs.value
}

final class BooleanValue : Node, Value, Equatable {
    let kind: Kind = .booleanValue
    let loc: Location?
    let value: Bool

    init(loc: Location? = nil, value: Bool) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: BooleanValue, rhs: BooleanValue) -> Bool {
    return lhs.value == rhs.value
}

final class EnumValue : Node, Value, Equatable {
    let kind: Kind = .enumValue
    let loc: Location?
    let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

func == (lhs: EnumValue, rhs: EnumValue) -> Bool {
    return lhs.value == rhs.value
}

final class ListValue : Node, Value, Equatable {
    let kind: Kind = .listValue
    let loc: Location?
    let values: [Value]

    init(loc: Location? = nil, values: [Value]) {
        self.loc = loc
        self.values = values
    }
}

func == (lhs: ListValue, rhs: ListValue) -> Bool {
    guard lhs.values.count == rhs.values.count else {
        return false
    }

    for (l, r) in zip(lhs.values, rhs.values) {
        guard l == r else {
            return false
        }
    }

    return true
}

final class ObjectValue : Node, Value, Equatable {
    let kind: Kind = .objectValue
    let loc: Location?
    let fields: [ObjectField]

    init(loc: Location? = nil, fields: [ObjectField]) {
        self.loc = loc
        self.fields = fields
    }
}

func == (lhs: ObjectValue, rhs: ObjectValue) -> Bool {
    return lhs.fields == rhs.fields
}

final class ObjectField : Node, Equatable {
    let kind: Kind = .objectField
    let loc: Location?
    let name: Name
    let value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }
}

func == (lhs: ObjectField, rhs: ObjectField) -> Bool {
    return lhs.name == rhs.name &&
           lhs.value == rhs.value
}

// Directives
final class Directive : Node, Equatable {
    let kind: Kind = .directive
    let loc: Location?
    let name: Name
    let arguments: [Argument]

    init(loc: Location? = nil, name: Name, arguments: [Argument] = []) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
    }
}

func == (lhs: Directive, rhs: Directive) -> Bool {
    return lhs.name == rhs.name &&
           lhs.arguments == rhs.arguments
}


// Type Reference
protocol Type : Node {}
//NamedType
//    | ListType
//    | NonNullType

func == (lhs: Type, rhs: Type) -> Bool {
    switch lhs {
    case let l as NamedType:
        if let r = rhs as? NamedType {
            return l == r
        }
    case let l as ListType:
        if let r = rhs as? ListType {
            return l == r
        }
    case let l as NonNullType:
        if let r = rhs as? NonNullType {
            return l == r
        }
    default:
        return false
    }

    return false
}

final class NamedType : Node, Type, NonNullableType, Equatable {
    let kind: Kind = .namedType
    let loc: Location?
    let name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }
}

func == (lhs: NamedType, rhs: NamedType) -> Bool {
    return lhs.name == rhs.name
}

final class ListType : Node, Type, NonNullableType, Equatable {
    let kind: Kind = .listType
    let loc: Location?
    let type: Type

    init(loc: Location? = nil, type: Type) {
        self.loc = loc
        self.type = type
    }
}

func == (lhs: ListType, rhs: ListType) -> Bool {
    return lhs.type == rhs.type
}

protocol NonNullableType : Type {}

final class NonNullType : Node, Type, Equatable {
    let kind: Kind = .nonNullType
    let loc: Location?
    let type: NonNullableType

    init(loc: Location? = nil, type: NonNullableType) {
        self.loc = loc
        self.type = type
    }
}

func == (lhs: NonNullType, rhs: NonNullType) -> Bool {
    return lhs.type == rhs.type
}

// Type System Definition
protocol TypeSystemDefinition : Definition {}
//= SchemaDefinition
//    | TypeDefinition
//    | TypeExtensionDefinition
//    | DirectiveDefinition

final class SchemaDefinition : Node, TypeSystemDefinition {
    let kind: Kind = .schemaDefinition
    let loc: Location?
    let directives: [Directive]
    let operationTypes: [OperationTypeDefinition]

    init(loc: Location? = nil, directives: [Directive], operationTypes: [OperationTypeDefinition]) {
        self.loc = loc
        self.directives = directives
        self.operationTypes = operationTypes
    }
}

final class OperationTypeDefinition : Node {
    let kind: Kind = .operationDefinition
    let loc: Location?
    let operation: OperationType
    let type: NamedType

    init(loc: Location? = nil, operation: OperationType, type: NamedType) {
        self.loc = loc
        self.operation = operation
        self.type = type
    }
}

protocol TypeDefinition : TypeSystemDefinition {}
//= ScalarTypeDefinition
//    | ObjectTypeDefinition
//    | InterfaceTypeDefinition
//    | UnionTypeDefinition
//    | EnumTypeDefinition
//    | InputObjectTypeDefinition

final class ScalarTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .scalarTypeDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }
}

final class ObjectTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .objectTypeDefinition
    let loc: Location?
    let name: Name
    let interfaces: [NamedType]
    let directives: [Directive]
    let fields: [FieldDefinition]

    init(loc: Location? = nil, name: Name, interfaces: [NamedType] = [], directives: [Directive] = [], fields: [FieldDefinition] = []) {
        self.loc = loc
        self.name = name
        self.interfaces = interfaces
        self.directives = directives
        self.fields = fields
    }
}

final class FieldDefinition : Node {
    let kind: Kind = .fieldDefinition
    let loc: Location?
    let name: Name
    let arguments: [InputValueDefinition]
    let type: Type
    let directives: [Directive]

    init(loc: Location? = nil,  name: Name, arguments: [InputValueDefinition] = [], type: Type, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
        self.type = type
        self.directives = directives
    }
}

final class InputValueDefinition : Node {
    let kind: Kind = .inputValueDefinition
    let loc: Location?
    let name: Name
    let type: Type
    let defaultValue: Value?
    let directives: [Directive]

    init(loc: Location? = nil, name: Name, type: Type, defaultValue: Value? = nil, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.directives = directives
    }
}

final class InterfaceTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .interfaceTypeDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]
    let fields: [FieldDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], fields: [FieldDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.fields = fields
    }
}

final class UnionTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .unionTypeDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]
    let types: [NamedType]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], types: [NamedType]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.types = types
    }
}

final class EnumTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .enumTypeDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]
    let values: [EnumValueDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], values: [EnumValueDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.values = values
    }
}

final class EnumValueDefinition : Node {
    let kind: Kind = .enumValueDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }
}

final class InputObjectTypeDefinition : Node, TypeDefinition {
    let kind: Kind = .inputObjectTypeDefinition
    let loc: Location?
    let name: Name
    let directives: [Directive]
    let fields: [InputValueDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], fields: [InputValueDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.fields = fields
    }
}

final class TypeExtensionDefinition : Node, TypeSystemDefinition {
    let kind: Kind = .typeExtensionDefinition
    let loc: Location?
    let definition: ObjectTypeDefinition

    init(loc: Location? = nil, definition: ObjectTypeDefinition) {
        self.loc = loc
        self.definition = definition
    }
}

final class DirectiveDefinition : Node, TypeSystemDefinition {
    let kind: Kind = .directiveDefinition
    let loc: Location?
    let name: Name
    let arguments: [InputValueDefinition]
    let locations: [Name]

    init(loc: Location? = nil, name: Name, arguments: [InputValueDefinition] = [], locations: [Name]) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
        self.locations = locations
    }
}
