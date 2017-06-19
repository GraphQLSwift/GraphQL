/**
 * Contains a range of UTF-8 character offsets and token references that
 * identify the region of the source from which the AST derived.
 */
public struct Location {

    /**
     * The character offset at which this Node begins.
     */
    public let start: Int

    /**
     * The character offset at which this Node ends.
     */
    public let end: Int

    /**
     * The Token at which this Node begins.
     */
    public let startToken: Token

    /**
     * The Token at which this Node ends.
     */
    public let endToken: Token

    /**
     * The Source document the AST represents.
     */
    public let source: Source
}

/**
 * Represents a range of characters represented by a lexical token
 * within a Source.
 */
final public class Token {
    public enum Kind : String, CustomStringConvertible {
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

        public var description: String {
            return rawValue
        }
    }

    /**
     * The kind of Token.
     */
    public let kind: Kind

    /**
     * The character offset at which this Node begins.
     */
    public let start: Int
    /**
     * The character offset at which this Node ends.
     */
    public let end: Int
    /**
     * The 1-indexed line number on which this Token appears.
     */
    public let line: Int
    /**
     * The 1-indexed column number at which this Token begins.
     */
    public let column: Int
    /**
     * For non-punctuation tokens, represents the interpreted value of the token.
     */
    public let value: String?
    /**
     * Tokens exist as nodes in a double-linked-list amongst all tokens
     * including ignored tokens. <SOF> is always the first node and <EOF>
     * the last.
     */
    public internal(set) weak var prev: Token?
    public internal(set) var next: Token?

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

extension Token : Equatable {
    public static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.kind   == rhs.kind   &&
            lhs.start  == rhs.start  &&
            lhs.end    == rhs.end    &&
            lhs.line   == rhs.line   &&
            lhs.column == rhs.column &&
            lhs.value  == rhs.value
    }
}

extension Token : CustomStringConvertible {
    public var description: String {
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

/**
 * The list of all possible AST node types.
 */
public protocol Node {
    var kind: Kind { get }
    var loc: Location? { get }
    func get(key: String) -> NodeResult?
    func set(value: Node?, key: String)
}

extension Node {
    public func get(key: String) -> NodeResult? {
        return nil
    }

    public func set(value: Node?, key: String) {

    }
}

extension Name                      : Node {}
extension Document                  : Node {}
extension OperationDefinition       : Node {}
extension VariableDefinition        : Node {}
extension Variable                  : Node {}
extension SelectionSet              : Node {}
extension Field                     : Node {}
extension Argument                  : Node {}
extension FragmentSpread            : Node {}
extension InlineFragment            : Node {}
extension FragmentDefinition        : Node {}
extension IntValue                  : Node {}
extension FloatValue                : Node {}
extension StringValue               : Node {}
extension BooleanValue              : Node {}
extension EnumValue                 : Node {}
extension ListValue                 : Node {}
extension ObjectValue               : Node {}
extension ObjectField               : Node {}
extension Directive                 : Node {}
extension NamedType                 : Node {}
extension ListType                  : Node {}
extension NonNullType               : Node {}
extension SchemaDefinition          : Node {}
extension OperationTypeDefinition   : Node {}
extension ScalarTypeDefinition      : Node {}
extension ObjectTypeDefinition      : Node {}
extension FieldDefinition           : Node {}
extension InputValueDefinition      : Node {}
extension InterfaceTypeDefinition   : Node {}
extension UnionTypeDefinition       : Node {}
extension EnumTypeDefinition        : Node {}
extension EnumValueDefinition       : Node {}
extension InputObjectTypeDefinition : Node {}
extension TypeExtensionDefinition   : Node {}
extension DirectiveDefinition       : Node {}

public final class Name {
    public let kind: Kind = .name
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

extension Name : Equatable {
    public static func == (lhs: Name, rhs: Name) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class Document {
    public let kind: Kind = .document
    public let loc: Location?
    public let definitions: [Definition]

    init(loc: Location? = nil, definitions: [Definition]) {
        self.loc = loc
        self.definitions = definitions
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "definitions":
            guard !definitions.isEmpty else {
                return nil
            }
            return .array(definitions)
        default:
            return nil
        }
    }
}

extension Document : Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
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
}

public protocol  Definition   : Node       {}
extension OperationDefinition : Definition {}
extension FragmentDefinition  : Definition {}

public func == (lhs: Definition, rhs: Definition) -> Bool {
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
            return l == r
        }
    default:
        return false
    }

    return false
}

public enum OperationType : String {
    case query = "query"
    case mutation = "mutation"
    // Note: subscription is an experimental non-spec addition.
    case subscription = "subscription"
}

public final class OperationDefinition {
    public let kind: Kind = .operationDefinition
    public let loc: Location?
    public let operation: OperationType
    public let name: Name?
    public let variableDefinitions: [VariableDefinition]
    public let directives: [Directive]
    public let selectionSet: SelectionSet

    init(loc: Location? = nil, operation: OperationType, name: Name? = nil, variableDefinitions: [VariableDefinition] = [], directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.operation = operation
        self.name = name
        self.variableDefinitions = variableDefinitions
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public func get(key: String) -> NodeResult? {
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
    }
}

extension OperationDefinition : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }

    public static func == (lhs: OperationDefinition, rhs: OperationDefinition) -> Bool {
        return lhs.operation == rhs.operation &&
            lhs.name == rhs.name &&
            lhs.variableDefinitions == rhs.variableDefinitions &&
            lhs.directives == rhs.directives &&
            lhs.selectionSet == rhs.selectionSet
    }
}

public final class VariableDefinition {
    public let kind: Kind = .variableDefinition
    public let loc: Location?
    public let variable: Variable
    public let type: Type
    public let defaultValue: Value?

    init(loc: Location? = nil, variable: Variable, type: Type, defaultValue: Value? = nil) {
        self.loc = loc
        self.variable = variable
        self.type = type
        self.defaultValue = defaultValue
    }

    public func get(key: String) -> NodeResult? {
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
    }
}

extension VariableDefinition : Equatable {
    public static func == (lhs: VariableDefinition, rhs: VariableDefinition) -> Bool {
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
}

public final class Variable {
    public let kind: Kind = .variable
    public let loc: Location?
    public let name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "name":
            return .node(name)
        default:
            return nil
        }
    }
}

extension Variable : Equatable {
    static public func == (lhs: Variable, rhs: Variable) -> Bool {
        return lhs.name == rhs.name
    }
}

public final class SelectionSet {
    public let kind: Kind = .selectionSet
    public let loc: Location?
    public let selections: [Selection]

    init(loc: Location? = nil, selections: [Selection]) {
        self.loc = loc
        self.selections = selections
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "selections":
            guard !selections.isEmpty else {
                return nil
            }
            return .array(selections)
        default:
            return nil
        }
    }
}

extension SelectionSet : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }

    public static func == (lhs: SelectionSet, rhs: SelectionSet) -> Bool {
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
}

public protocol Selection : Node      {}
extension Field           : Selection {}
extension FragmentSpread  : Selection {}
extension InlineFragment  : Selection {}

public func == (lhs: Selection, rhs: Selection) -> Bool {
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

public final class Field {
    public let kind: Kind = .field
    public let loc: Location?
    public let alias: Name?
    public let name: Name
    public let arguments: [Argument]
    public let directives: [Directive]
    public let selectionSet: SelectionSet?

    init(loc: Location? = nil, alias: Name? = nil, name: Name, arguments: [Argument] = [], directives: [Directive] = [], selectionSet: SelectionSet? = nil) {
        self.loc = loc
        self.alias = alias
        self.name = name
        self.arguments = arguments
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public func get(key: String) -> NodeResult? {
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
    }
}

extension Field : Equatable {
    public static func == (lhs: Field, rhs: Field) -> Bool {
        return lhs.alias == rhs.alias &&
            lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.directives == rhs.directives &&
            lhs.selectionSet == rhs.selectionSet
    }
}

public final class Argument {
    public let kind: Kind = .argument
    public let loc: Location?
    public let name: Name
    public let value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "name":
            return .node(name)
        case "value":
            return .node(value)
        default:
            return nil
        }
    }
}

extension Argument : Equatable {
    public static func == (lhs: Argument, rhs: Argument) -> Bool {
        return lhs.name == rhs.name &&
            lhs.value == rhs.value
    }
}

public protocol  Fragment : Selection {}
extension FragmentSpread  : Fragment  {}
extension InlineFragment  : Fragment  {}

public final class FragmentSpread {
    public let kind: Kind = .fragmentSpread
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "name":
            return .node(name)
        case "directives":
            guard !directives.isEmpty else {
                return nil
            }
            return .array(directives)
        default:
            return nil
        }
    }
}

extension FragmentSpread : Equatable {
    public static func == (lhs: FragmentSpread, rhs: FragmentSpread) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives
    }
}

public protocol HasTypeCondition {
    func getTypeCondition() -> NamedType?
}

extension InlineFragment : HasTypeCondition {
    public func getTypeCondition() -> NamedType? {
        return typeCondition
    }
}

extension FragmentDefinition : HasTypeCondition {
    public func getTypeCondition() -> NamedType? {
        return typeCondition
    }
}

public final class InlineFragment {
    public let kind: Kind = .inlineFragment
    public let loc: Location?
    public let typeCondition: NamedType?
    public let directives: [Directive]
    public let selectionSet: SelectionSet

    init(loc: Location? = nil, typeCondition: NamedType? = nil, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }
}

extension InlineFragment {
    public func get(key: String) -> NodeResult? {
        switch key {
        case "typeCondition":
            return typeCondition.map({ .node($0) })
        case "directives":
            guard !directives.isEmpty else {
                return nil
            }
            return .array(directives)
        case "selectionSet":
            return .node(selectionSet)
        default:
            return nil
        }
    }
}

extension InlineFragment : Equatable {
    public static func == (lhs: InlineFragment, rhs: InlineFragment) -> Bool {
        return lhs.typeCondition == rhs.typeCondition &&
        lhs.directives == rhs.directives &&
        lhs.selectionSet == rhs.selectionSet
    }
}

public final class FragmentDefinition {
    public let kind: Kind = .fragmentDefinition
    public let loc: Location?
    public let name: Name
    public let typeCondition: NamedType
    public let directives: [Directive]
    public let selectionSet: SelectionSet

    init(loc: Location? = nil, name: Name, typeCondition: NamedType, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.name = name
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "name":
            return .node(name)
        case "typeCondition":
            return .node(typeCondition)
        case "directives":
            guard !directives.isEmpty else {
                return nil
            }
            return .array(directives)
        case "selectionSet":
            return .node(selectionSet)
        default:
            return nil
        }
    }
}

extension FragmentDefinition : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }

    public static func == (lhs: FragmentDefinition, rhs: FragmentDefinition) -> Bool {
        return lhs.name == rhs.name &&
        lhs.typeCondition == rhs.typeCondition &&
        lhs.directives == rhs.directives &&
        lhs.selectionSet == rhs.selectionSet
    }
}

public protocol Value  : Node  {}
extension Variable     : Value {}
extension IntValue     : Value {}
extension FloatValue   : Value {}
extension StringValue  : Value {}
extension BooleanValue : Value {}
extension EnumValue    : Value {}
extension ListValue    : Value {}
extension ObjectValue  : Value {}

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

public final class IntValue {
    public let kind: Kind = .intValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

extension IntValue : Equatable {
    public static func == (lhs: IntValue, rhs: IntValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class FloatValue {
    public let kind: Kind = .floatValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

extension FloatValue : Equatable {
    public static func == (lhs: FloatValue, rhs: FloatValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class StringValue {
    public let kind: Kind = .stringValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

extension StringValue : Equatable {
    public static func == (lhs: StringValue, rhs: StringValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class BooleanValue {
    public let kind: Kind = .booleanValue
    public let loc: Location?
    public let value: Bool

    init(loc: Location? = nil, value: Bool) {
        self.loc = loc
        self.value = value
    }
}

extension BooleanValue : Equatable {
    public static func == (lhs: BooleanValue, rhs: BooleanValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class EnumValue {
    public let kind: Kind = .enumValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
}

extension EnumValue : Equatable {
    public static func == (lhs: EnumValue, rhs: EnumValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public final class ListValue {
    public let kind: Kind = .listValue
    public let loc: Location?
    public let values: [Value]

    init(loc: Location? = nil, values: [Value]) {
        self.loc = loc
        self.values = values
    }
}

extension ListValue : Equatable {
    public static func == (lhs: ListValue, rhs: ListValue) -> Bool {
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
}

public final class ObjectValue {
    public let kind: Kind = .objectValue
    public let loc: Location?
    public let fields: [ObjectField]

    init(loc: Location? = nil, fields: [ObjectField]) {
        self.loc = loc
        self.fields = fields
    }
}

extension ObjectValue : Equatable {
    public static func == (lhs: ObjectValue, rhs: ObjectValue) -> Bool {
        return lhs.fields == rhs.fields
    }
}

public final class ObjectField {
    public let kind: Kind = .objectField
    public let loc: Location?
    public let name: Name
    public let value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }
}

extension ObjectField : Equatable {
    public static func == (lhs: ObjectField, rhs: ObjectField) -> Bool {
        return lhs.name == rhs.name &&
            lhs.value == rhs.value
    }
}

public final class Directive {
    public let kind: Kind = .directive
    public let loc: Location?
    public let name: Name
    public let arguments: [Argument]

    init(loc: Location? = nil, name: Name, arguments: [Argument] = []) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
    }
}

extension Directive : Equatable {
    public static func == (lhs: Directive, rhs: Directive) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments
    }
}

public protocol  Type : Node {}
extension NamedType   : Type {}
extension ListType    : Type {}
extension NonNullType : Type {}

public func == (lhs: Type, rhs: Type) -> Bool {
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

public final class NamedType {
    public let kind: Kind = .namedType
    public let loc: Location?
    public let name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "name":
            return .node(name)
        default:
            return nil
        }
    }
}

extension NamedType : Equatable {
    public static func == (lhs: NamedType, rhs: NamedType) -> Bool {
        return lhs.name == rhs.name
    }
}

public final class ListType {
    public let kind: Kind = .listType
    public let loc: Location?
    public let type: Type

    init(loc: Location? = nil, type: Type) {
        self.loc = loc
        self.type = type
    }
}

extension ListType : Equatable {
    public static func == (lhs: ListType, rhs: ListType) -> Bool {
        return lhs.type == rhs.type
    }
}

public protocol NonNullableType : Type {}
extension ListType              : NonNullableType {}
extension NamedType             : NonNullableType {}

public final class NonNullType {
    public let kind: Kind = .nonNullType
    public let loc: Location?
    public let type: NonNullableType

    init(loc: Location? = nil, type: NonNullableType) {
        self.loc = loc
        self.type = type
    }

    public func get(key: String) -> NodeResult? {
        switch key {
        case "type":
            return .node(type)
        default:
            return nil
        }
    }
}

extension NonNullType : Equatable {
    public static func == (lhs: NonNullType, rhs: NonNullType) -> Bool {
        return lhs.type == rhs.type
    }
}

// Type System Definition
// experimental non-spec addition.
public protocol  TypeSystemDefinition : Definition           {}
extension SchemaDefinition            : TypeSystemDefinition {}
extension TypeExtensionDefinition     : TypeSystemDefinition {}
extension DirectiveDefinition         : TypeSystemDefinition {}

public func == (lhs: TypeSystemDefinition, rhs: TypeSystemDefinition) -> Bool {
    switch lhs {
    case let l as SchemaDefinition:
        if let r = rhs as? SchemaDefinition {
            return l == r
        }
    case let l as TypeExtensionDefinition:
        if let r = rhs as? TypeExtensionDefinition {
            return l == r
        }
    case let l as DirectiveDefinition:
        if let r = rhs as? DirectiveDefinition {
            return l == r
        }
    case let l as TypeDefinition:
        if let r = rhs as? TypeDefinition {
            return l == r
        }
    default:
        return false
    }

    return false
}

public final class SchemaDefinition {
    public let kind: Kind = .schemaDefinition
    public let loc: Location?
    public let directives: [Directive]
    public let operationTypes: [OperationTypeDefinition]

    init(loc: Location? = nil, directives: [Directive], operationTypes: [OperationTypeDefinition]) {
        self.loc = loc
        self.directives = directives
        self.operationTypes = operationTypes
    }
}

extension SchemaDefinition : Equatable {
    public static func == (lhs: SchemaDefinition, rhs: SchemaDefinition) -> Bool {
        return lhs.directives == rhs.directives &&
        lhs.operationTypes == rhs.operationTypes
    }
}

public final class OperationTypeDefinition {
    public let kind: Kind = .operationDefinition
    public let loc: Location?
    public let operation: OperationType
    public let type: NamedType

    init(loc: Location? = nil, operation: OperationType, type: NamedType) {
        self.loc = loc
        self.operation = operation
        self.type = type
    }
}

extension OperationTypeDefinition : Equatable {
    public static func == (lhs: OperationTypeDefinition, rhs: OperationTypeDefinition) -> Bool {
        return lhs.operation == rhs.operation &&
            lhs.type == rhs.type
    }
}

public protocol  TypeDefinition     : TypeSystemDefinition {}
extension ScalarTypeDefinition      : TypeDefinition       {}
extension ObjectTypeDefinition      : TypeDefinition       {}
extension InterfaceTypeDefinition   : TypeDefinition       {}
extension UnionTypeDefinition       : TypeDefinition       {}
extension EnumTypeDefinition        : TypeDefinition       {}
extension InputObjectTypeDefinition : TypeDefinition       {}

public func == (lhs: TypeDefinition, rhs: TypeDefinition) -> Bool {
    switch lhs {
    case let l as ScalarTypeDefinition:
        if let r = rhs as? ScalarTypeDefinition {
            return l == r
        }
    case let l as ObjectTypeDefinition:
        if let r = rhs as? ObjectTypeDefinition {
            return l == r
        }
    case let l as InterfaceTypeDefinition:
        if let r = rhs as? InterfaceTypeDefinition {
            return l == r
        }
    case let l as UnionTypeDefinition:
        if let r = rhs as? UnionTypeDefinition {
            return l == r
        }
    case let l as EnumTypeDefinition:
        if let r = rhs as? EnumTypeDefinition {
            return l == r
        }
    case let l as InputObjectTypeDefinition:
        if let r = rhs as? InputObjectTypeDefinition {
            return l == r
        }
    default:
        return false
    }

    return false
}

public final class ScalarTypeDefinition {
    public let kind: Kind = .scalarTypeDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }
}

extension ScalarTypeDefinition : Equatable {
    public static func == (lhs: ScalarTypeDefinition, rhs: ScalarTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives
    }
}

public final class ObjectTypeDefinition {
    public let kind: Kind = .objectTypeDefinition
    public let loc: Location?
    public let name: Name
    public let interfaces: [NamedType]
    public let directives: [Directive]
    public let fields: [FieldDefinition]

    init(loc: Location? = nil, name: Name, interfaces: [NamedType] = [], directives: [Directive] = [], fields: [FieldDefinition] = []) {
        self.loc = loc
        self.name = name
        self.interfaces = interfaces
        self.directives = directives
        self.fields = fields
    }
}

extension ObjectTypeDefinition : Equatable {
    public static func == (lhs: ObjectTypeDefinition, rhs: ObjectTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.interfaces == rhs.interfaces &&
            lhs.directives == rhs.directives &&
            lhs.fields == rhs.fields
    }
}

public final class FieldDefinition {
    public let kind: Kind = .fieldDefinition
    public let loc: Location?
    public let name: Name
    public let arguments: [InputValueDefinition]
    public let type: Type
    public let directives: [Directive]

    init(loc: Location? = nil,  name: Name, arguments: [InputValueDefinition] = [], type: Type, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
        self.type = type
        self.directives = directives
    }
}

extension FieldDefinition : Equatable {
    public static func == (lhs: FieldDefinition, rhs: FieldDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.type == rhs.type &&
            lhs.directives == rhs.directives
    }
}

public final class InputValueDefinition {
    public let kind: Kind = .inputValueDefinition
    public let loc: Location?
    public let name: Name
    public let type: Type
    public let defaultValue: Value?
    public let directives: [Directive]

    init(loc: Location? = nil, name: Name, type: Type, defaultValue: Value? = nil, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.directives = directives
    }
}

extension InputValueDefinition : Equatable {
    public static func == (lhs: InputValueDefinition, rhs: InputValueDefinition) -> Bool {
        guard lhs.name == rhs.name else {
            return false
        }

        guard lhs.type == rhs.type else {
            return false
        }

        guard lhs.directives == rhs.directives else {
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
}

public final class InterfaceTypeDefinition {
    public let kind: Kind = .interfaceTypeDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]
    public let fields: [FieldDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], fields: [FieldDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.fields = fields
    }
}

extension InterfaceTypeDefinition : Equatable {
    public static func == (lhs: InterfaceTypeDefinition, rhs: InterfaceTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.fields == rhs.fields
    }
}

public final class UnionTypeDefinition {
    public let kind: Kind = .unionTypeDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]
    public let types: [NamedType]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], types: [NamedType]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.types = types
    }
}

extension UnionTypeDefinition : Equatable {
    public static func == (lhs: UnionTypeDefinition, rhs: UnionTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.types == rhs.types
    }
}

public final class EnumTypeDefinition {
    public let kind: Kind = .enumTypeDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]
    public let values: [EnumValueDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], values: [EnumValueDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.values = values
    }
}

extension EnumTypeDefinition : Equatable {
    public static func == (lhs: EnumTypeDefinition, rhs: EnumTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.values == rhs.values
    }
}

public final class EnumValueDefinition {
    public let kind: Kind = .enumValueDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }
}

extension EnumValueDefinition : Equatable {
    public static func == (lhs: EnumValueDefinition, rhs: EnumValueDefinition) -> Bool {
        return lhs.name == rhs.name &&
            lhs.directives == rhs.directives
    }
}

public final class InputObjectTypeDefinition {
    public let kind: Kind = .inputObjectTypeDefinition
    public let loc: Location?
    public let name: Name
    public let directives: [Directive]
    public let fields: [InputValueDefinition]

    init(loc: Location? = nil, name: Name, directives: [Directive] = [], fields: [InputValueDefinition]) {
        self.loc = loc
        self.name = name
        self.directives = directives
        self.fields = fields
    }
}

extension InputObjectTypeDefinition : Equatable {
    public static func == (lhs: InputObjectTypeDefinition, rhs: InputObjectTypeDefinition) -> Bool {
        return lhs.name == rhs.name &&
        lhs.directives == rhs.directives &&
        lhs.fields == rhs.fields
    }
}

public final class TypeExtensionDefinition {
    public let kind: Kind = .typeExtensionDefinition
    public let loc: Location?
    public let definition: ObjectTypeDefinition

    init(loc: Location? = nil, definition: ObjectTypeDefinition) {
        self.loc = loc
        self.definition = definition
    }
}

extension TypeExtensionDefinition : Equatable {
    public static func == (lhs: TypeExtensionDefinition, rhs: TypeExtensionDefinition) -> Bool {
        return lhs.definition == rhs.definition
    }
}

public final class DirectiveDefinition {
    public let kind: Kind = .directiveDefinition
    public let loc: Location?
    public let name: Name
    public let arguments: [InputValueDefinition]
    public let locations: [Name]
    
    init(loc: Location? = nil, name: Name, arguments: [InputValueDefinition] = [], locations: [Name]) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
        self.locations = locations
    }
}

extension DirectiveDefinition : Equatable {
    public static func == (lhs: DirectiveDefinition, rhs: DirectiveDefinition) -> Bool {
        return lhs.name == rhs.name &&
        lhs.arguments == rhs.arguments &&
        lhs.locations == rhs.locations
    }
}
