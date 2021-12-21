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
        case blockstring = "BlockString"
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

/**
 * The list of all possible AST node types.
 */
public protocol Node: TextOutputStreamable {
    var loc: Location? { get }
    mutating func descend(descender: inout Descender)
}

extension Node {
    var printed: String {
        var s = ""
        self.write(to: &s)
        return s
    }
}

private protocol EnumNode: Node {
    var underlyingNode: Node { get }
}
extension EnumNode {
    public var loc: Location? { underlyingNode.loc }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        underlyingNode.write(to: &target)
    }
}

extension Name                      : Node {}
extension Document                  : Node {}
extension OperationDefinition       : Node {}
extension VariableDefinition        : Node {}
extension Variable                  : Node {}
extension SelectionSet              : Node {}
extension Selection                 : Node {}
extension Field                     : Node {}
extension Argument                  : Node {}
extension FragmentSpread            : Node {}
extension InlineFragment            : Node {}
extension FragmentDefinition        : Node {}
extension Value                     : Node {}
extension IntValue                  : Node {}
extension FloatValue                : Node {}
extension StringValue               : Node {}
extension BooleanValue              : Node {}
extension NullValue                 : Node {}
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

public struct Name {
    public let kind: Kind = .name
    public let loc: Location?
    public let value: String

    public init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write(value)
    }
}

extension Name: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    public static func == (lhs: Name, rhs: Name) -> Bool {
        return lhs.value == rhs.value
    }
}

public struct Document {
    public let kind: Kind = .document
    public let loc: Location?
    public var definitions: [Definition]

    init(loc: Location? = nil, definitions: [Definition]) {
        self.loc = loc
        self.definitions = definitions
    }

    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.definitions)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        definitions.forEach {
            $0.write(to: &target)
            target.write("\n\n")
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

public enum Definition: EnumNode, Equatable {
    case executableDefinition(ExecutableDefinition)
    case typeSystemDefinitionOrExtension(TypeSystemDefinitionOrExtension)

    var underlyingNode: Node {
        switch self {
        case let .executableDefinition(x):
            return x
        case let .typeSystemDefinitionOrExtension(x):
            return x
        }
    }

    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .executableDefinition(x):
            descender.descend(enumCase: &x)
            self = .executableDefinition(x)
        case var .typeSystemDefinitionOrExtension(x):
            descender.descend(enumCase: &x)
            self = .typeSystemDefinitionOrExtension(x)
        }
    }
}

public enum ExecutableDefinition: EnumNode, Equatable {
    case operation(OperationDefinition)
    case fragment(FragmentDefinition)

    fileprivate var underlyingNode: Node {
        switch self {
        case let .fragment(fragmentDef):
            return fragmentDef
        case let .operation(operationDef):
            return operationDef
        }
    }

    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .fragment(x):
            descender.descend(enumCase: &x)
            self = .fragment(x)
        case var .operation(x):
            descender.descend(enumCase: &x)
            self = .operation(x)
        }
    }
}

public enum TypeSystemDefinitionOrExtension: EnumNode, Equatable {
    case typeSystemDefinition(TypeSystemDefinition)

    fileprivate var underlyingNode: Node {
        switch self {
        case let .typeSystemDefinition(x):
            return x
        }
    }

    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .typeSystemDefinition(x):
            descender.descend(enumCase: &x)
            self = .typeSystemDefinition(x)
        }
    }
}

public enum OperationType : String {
    case query = "query"
    case mutation = "mutation"
    // Note: subscription is an experimental non-spec addition.
    case subscription = "subscription"
}

public struct OperationDefinition {
    public let kind: Kind = .operationDefinition
    public let loc: Location?
    public var operation: OperationType
    public var name: Name?
    public var variableDefinitions: [VariableDefinition]
    public var directives: [Directive]
    public var selectionSet: SelectionSet

    init(loc: Location? = nil, operation: OperationType, name: Name? = nil, variableDefinitions: [VariableDefinition] = [], directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.operation = operation
        self.name = name
        self.variableDefinitions = variableDefinitions
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.variableDefinitions)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.selectionSet)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        let anonymous = operation == .query && directives.isEmpty && variableDefinitions.isEmpty
        if !anonymous {
            target.write(operation.rawValue)
            target.write(" ")
            name?.write(to: &target)
            if let first = variableDefinitions.first {
                target.write(" (")
                first.write(to: &target)
                variableDefinitions.suffix(from: 1).forEach {
                    target.write(", ")
                    $0.write(to: &target)
                }
                target.write(")")
            }
            if !directives.isEmpty {
                directives.write(to: &target)
            }
        }
        target.write(" ")
        selectionSet.write(to: &target)
    }
}

extension OperationDefinition: Equatable {
    public static func == (lhs: OperationDefinition, rhs: OperationDefinition) -> Bool {
        return lhs.operation == rhs.operation &&
        lhs.name == rhs.name &&
        lhs.variableDefinitions == rhs.variableDefinitions &&
        lhs.directives == rhs.directives &&
        lhs.selectionSet == rhs.selectionSet
    }
}

public struct VariableDefinition {
    public let kind: Kind = .variableDefinition
    public let loc: Location?
    public var variable: Variable
    public var type: Type
    public var defaultValue: Value?

    init(loc: Location? = nil, variable: Variable, type: Type, defaultValue: Value? = nil) {
        self.loc = loc
        self.variable = variable
        self.type = type
        self.defaultValue = defaultValue
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.variable)
        descender.descend(&self, \.type)
        descender.descend(&self, \.defaultValue)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        variable.write(to: &target)
        target.write(": ")
        type.write(to: &target)
        if let defaultValue = defaultValue {
            target.write(" = ")
            defaultValue.write(to: &target)
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

public struct Variable {
    public let kind: Kind = .variable
    public let loc: Location?
    public var name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("$")
        name.write(to: &target)
    }
}

extension Variable : Equatable {
    static public func == (lhs: Variable, rhs: Variable) -> Bool {
        return lhs.name == rhs.name
    }
}

public struct SelectionSet {
    public let kind: Kind = .selectionSet
    public let loc: Location?
    public var selections: [Selection]

    public init(loc: Location? = nil, selections: [Selection]) {
        self.loc = loc
        self.selections = selections
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.selections)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("{\n")
        selections.forEach {
            $0.write(to: &target)
            target.write("\n")
        }
        target.write("}")
    }
}

extension SelectionSet: Equatable {
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

public enum Selection: EnumNode, Equatable {
    case field(Field)
    case fragmentSpread(FragmentSpread)
    case inlineFragment(InlineFragment)
    
    fileprivate var underlyingNode: Node {
        switch self {
        case let .field(field):
            return field
        case let .fragmentSpread(fragmentSpread):
            return fragmentSpread
        case let .inlineFragment(inlineFragment):
            return inlineFragment
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .field(x):
            descender.descend(enumCase: &x)
            self = .field(x)
        case var .fragmentSpread(x):
            descender.descend(enumCase: &x)
            self = .fragmentSpread(x)
        case var .inlineFragment(x):
            descender.descend(enumCase: &x)
            self = .inlineFragment(x)
        }
    }
}

public struct Field {
    public let kind: Kind = .field
    public let loc: Location?
    public var alias: Name?
    public var name: Name
    public var arguments: [Argument]
    public var directives: [Directive]
    public var selectionSet: SelectionSet?

    public init(loc: Location? = nil, alias: Name? = nil, name: Name, arguments: [Argument] = [], directives: [Directive] = [], selectionSet: SelectionSet? = nil) {
        self.loc = loc
        self.alias = alias
        self.name = name
        self.arguments = arguments
        self.directives = directives
        self.selectionSet = selectionSet
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.alias)
        descender.descend(&self, \.name)
        descender.descend(&self, \.arguments)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.selectionSet)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        if let alias = alias {
            alias.write(to: &target)
            target.write(": ")
        }
        name.write(to: &target)
        if !arguments.isEmpty {
            target.write( "(")
            arguments.write(to: &target)
            target.write(")")
        }
        if !directives.isEmpty {
            target.write(" ")
            directives.write(to: &target)
        }
        if let selectionSet = selectionSet {
            target.write(" ")
            selectionSet.write(to: &target)
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

public struct Argument {
    public let kind: Kind = .argument
    public let loc: Location?
    public var name: Name
    public var value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.value)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        name.write(to: &target)
        target.write(": ")
        value.write(to: &target)
    }
}

extension Array where Element == Argument {
    func write<Target>(to target: inout Target) where Target : TextOutputStream {
        if let first = first {
            first.write(to: &target)
        }
        suffix(from: 1).forEach {
            target.write(", ")
            $0.write(to: &target)
        }
    }
}

extension Argument : Equatable {
    public static func == (lhs: Argument, rhs: Argument) -> Bool {
        return lhs.name == rhs.name &&
            lhs.value == rhs.value
    }
}

public struct FragmentSpread {
    public let kind: Kind = .fragmentSpread
    public let loc: Location?
    public var name: Name
    public var directives: [Directive]

    init(loc: Location? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.name = name
        self.directives = directives
    }

    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("...")
        name.write(to: &target)
        if !directives.isEmpty {
            target.write(" ")
            directives.write(to: &target)
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

public struct InlineFragment {
    public let kind: Kind = .inlineFragment
    public let loc: Location?
    public var typeCondition: NamedType?
    public var directives: [Directive]
    public var selectionSet: SelectionSet

    init(loc: Location? = nil, typeCondition: NamedType? = nil, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.typeCondition)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.selectionSet)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("...")
        if let typeCondition = typeCondition {
            target.write(" on ")
            typeCondition.write(to: &target)
        }
        if !directives.isEmpty {
            target.write(" ")
            directives.write(to: &target)
        }
        target.write(" ")
        selectionSet.write(to: &target)
    }
}

extension InlineFragment : Equatable {
    public static func == (lhs: InlineFragment, rhs: InlineFragment) -> Bool {
        return lhs.typeCondition == rhs.typeCondition &&
        lhs.directives == rhs.directives &&
        lhs.selectionSet == rhs.selectionSet
    }
}

public struct FragmentDefinition {
    public let kind: Kind = .fragmentDefinition
    public let loc: Location?
    public var name: Name
    public var typeCondition: NamedType
    public var directives: [Directive]
    public var selectionSet: SelectionSet

    init(loc: Location? = nil, name: Name, typeCondition: NamedType, directives: [Directive] = [], selectionSet: SelectionSet) {
        self.loc = loc
        self.name = name
        self.typeCondition = typeCondition
        self.directives = directives
        self.selectionSet = selectionSet
    }

    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.typeCondition)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.selectionSet)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("fragment ")
        name.write(to: &target)
        target.write(" on ")
        typeCondition.write(to: &target)
        if !directives.isEmpty {
            target.write(" ")
            directives.write(to: &target)
        }
        target.write(" ")
        selectionSet.write(to: &target)
    }
}

extension FragmentDefinition: Equatable {
    public static func == (lhs: FragmentDefinition, rhs: FragmentDefinition) -> Bool {
        return lhs.name == rhs.name &&
        lhs.typeCondition == rhs.typeCondition &&
        lhs.directives == rhs.directives &&
        lhs.selectionSet == rhs.selectionSet
    }
}

public enum Value: EnumNode, Equatable {
    var underlyingNode: Node {
        switch self {
        case let .variable(x):
            return x
        case let .intValue(x):
            return x
        case let .floatValue(x):
            return x
        case let .stringValue(x):
            return x
        case let .booleanValue(x):
            return x
        case let .nullValue(x):
            return x
        case let .enumValue(x):
            return x
        case let .listValue(x):
            return x
        case let .objectValue(x):
            return x
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .variable(x):
            descender.descend(enumCase: &x)
            self = .variable(x)
        case var .intValue(x):
            descender.descend(enumCase: &x)
            self = .intValue(x)
        case var .floatValue(x):
            descender.descend(enumCase: &x)
            self = .floatValue(x)
        case var .stringValue(x):
            descender.descend(enumCase: &x)
            self = .stringValue(x)
        case var .booleanValue(x):
            descender.descend(enumCase: &x)
            self = .booleanValue(x)
        case var .nullValue(x):
            descender.descend(enumCase: &x)
            self = .nullValue(x)
        case var .enumValue(x):
            descender.descend(enumCase: &x)
            self = .enumValue(x)
        case var .listValue(x):
            descender.descend(enumCase: &x)
            self = .listValue(x)
        case var .objectValue(x):
            descender.descend(enumCase: &x)
            self = .objectValue(x)
        }
    }
    
    case variable(Variable)
    case intValue(IntValue)
    case floatValue(FloatValue)
    case stringValue(StringValue)
    case booleanValue(BooleanValue)
    case nullValue(NullValue)
    case enumValue(EnumValue)
    case listValue(ListValue)
    case objectValue(ObjectValue)
}

public struct IntValue {
    public let kind: Kind = .intValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write(value)
    }
}

extension IntValue : Equatable {
    public static func == (lhs: IntValue, rhs: IntValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public struct FloatValue {
    public let kind: Kind = .floatValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write(value)
    }
}

extension FloatValue : Equatable {
    public static func == (lhs: FloatValue, rhs: FloatValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public struct StringValue {
    public let kind: Kind = .stringValue
    public let loc: Location?
    public let value: String
    public let block: Bool?

    init(loc: Location? = nil, value: String, block: Bool? = nil) {
        self.loc = loc
        self.value = value
        self.block = block
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        if block ?? false {
            //TODO: Implement this!
            fatalError("Needs implemented")
        } else {
            target.write("\"")
            target.write(value)
            target.write("\"")
        }
    }
}

extension StringValue : Equatable {
    public static func == (lhs: StringValue, rhs: StringValue) -> Bool {
        return lhs.value == rhs.value && lhs.block == rhs.block
    }
}

public struct BooleanValue {
    public let kind: Kind = .booleanValue
    public let loc: Location?
    public let value: Bool

    init(loc: Location? = nil, value: Bool) {
        self.loc = loc
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write(value ? "true" : "false")
    }
}

extension BooleanValue : Equatable {
    public static func == (lhs: BooleanValue, rhs: BooleanValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public struct NullValue {
    public let kind: Kind = .nullValue
    public let loc: Location?

    init(loc: Location? = nil) {
        self.loc = loc
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("null")
    }
}

extension NullValue : Equatable {
    public static func == (lhs: NullValue, rhs: NullValue) -> Bool {
        return true
    }
}

public struct EnumValue {
    public let kind: Kind = .enumValue
    public let loc: Location?
    public let value: String

    init(loc: Location? = nil, value: String) {
        self.loc = loc
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) { }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write(value)
    }
}

extension EnumValue : Equatable {
    public static func == (lhs: EnumValue, rhs: EnumValue) -> Bool {
        return lhs.value == rhs.value
    }
}

public struct ListValue {
    public let kind: Kind = .listValue
    public let loc: Location?
    public var values: [Value]

    init(loc: Location? = nil, values: [Value]) {
        self.loc = loc
        self.values = values
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.values)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("[")
        if let first = values.first {
            first.write(to: &target)
            values.suffix(from: 1).forEach {
                target.write(", ")
                $0.write(to: &target)
            }
        }
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

public struct ObjectValue {
    public let kind: Kind = .objectValue
    public let loc: Location?
    public var fields: [ObjectField]

    init(loc: Location? = nil, fields: [ObjectField]) {
        self.loc = loc
        self.fields = fields
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.fields)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("{")
        if let first = fields.first {
            first.write(to: &target)
            fields.suffix(from: 1).forEach {
                target.write(", ")
                $0.write(to: &target)
            }
        }
        target.write("}")
    }
}

extension ObjectValue : Equatable {
    public static func == (lhs: ObjectValue, rhs: ObjectValue) -> Bool {
        return lhs.fields == rhs.fields
    }
}

public struct ObjectField {
    public let kind: Kind = .objectField
    public let loc: Location?
    public var name: Name
    public var value: Value

    init(loc: Location? = nil, name: Name, value: Value) {
        self.loc = loc
        self.name = name
        self.value = value
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.value)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        name.write(to: &target)
        target.write(": ")
        value.write(to: &target)
    }
}

extension ObjectField : Equatable {
    public static func == (lhs: ObjectField, rhs: ObjectField) -> Bool {
        return lhs.name == rhs.name &&
            lhs.value == rhs.value
    }
}

public struct Directive {
    public let kind: Kind = .directive
    public let loc: Location?
    public var name: Name
    public var arguments: [Argument]

    init(loc: Location? = nil, name: Name, arguments: [Argument] = []) {
        self.loc = loc
        self.name = name
        self.arguments = arguments
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
        descender.descend(&self, \.arguments)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("@")
        name.write(to: &target)
        if !arguments.isEmpty {
            target.write("(")
            arguments.write(to: &target)
            target.write(")")
        }
    }
}

extension Directive : Equatable {
    public static func == (lhs: Directive, rhs: Directive) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments
    }
}

extension Array where Element == Directive {
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        if let first = first {
            first.write(to: &target)
            suffix(from: 1).forEach {
                $0.write(to: &target)
                target.write(" ")
            }
        }
    }
}

public indirect enum Type: EnumNode, Equatable {
    var underlyingNode: Node {
        switch self {
        case let .namedType(x):
            return x
        case let .listType(x):
            return x
        case let .nonNullType(x):
            return x
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .namedType(x):
            descender.descend(enumCase: &x)
            self = .namedType(x)
        case var .listType(x):
            descender.descend(enumCase: &x)
            self = .listType(x)
        case var .nonNullType(x):
            descender.descend(enumCase: &x)
            self = .nonNullType(x)
        }
    }
    
    case namedType(NamedType)
    case listType(ListType)
    case nonNullType(NonNullType)
}

public struct NamedType {
    public let kind: Kind = .namedType
    public let loc: Location?
    public var name: Name

    init(loc: Location? = nil, name: Name) {
        self.loc = loc
        self.name = name
    }

    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.name)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        name.write(to: &target)
    }
}

extension NamedType : Equatable {
    public static func == (lhs: NamedType, rhs: NamedType) -> Bool {
        return lhs.name == rhs.name
    }
}

public struct ListType {
    public let kind: Kind = .listType
    public let loc: Location?
    public var type: Type

    init(loc: Location? = nil, type: Type) {
        self.loc = loc
        self.type = type
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.type)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        target.write("[")
        type.write(to: &target)
        target.write("]")
    }
}

extension ListType : Equatable {
    public static func == (lhs: ListType, rhs: ListType) -> Bool {
        return lhs.type == rhs.type
    }
}

public enum NonNullType: EnumNode, Equatable {
    var underlyingNode: Node {
        switch self {
        case let .namedType(x):
            return x
        case let .listType(x):
            return x
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .namedType(x):
            descender.descend(enumCase: &x)
            self = .namedType(x)
        case var .listType(x):
            descender.descend(enumCase: &x)
            self = .listType(x)
        }
    }
    
    case namedType(NamedType)
    case listType(ListType)
    
    var type: Type {
        switch self {
        case let .namedType(x):
            return .namedType(x)
        case let .listType(x):
            return .listType(x)
        }
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        type.write(to: &target)
        target.write("!")
    }
}

public enum TypeSystemDefinition: EnumNode, Equatable {
    var underlyingNode: Node {
        switch self {
        case let .schemaDefinition(x):
            return x
        case let .typeDefinition(x):
            return x
        case let .directiveDefinition(x):
            return x
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .schemaDefinition(x):
            descender.descend(enumCase: &x)
            self = .schemaDefinition(x)
        case var .typeDefinition(x):
            descender.descend(enumCase: &x)
            self = .typeDefinition(x)
        case var .directiveDefinition(x):
            descender.descend(enumCase: &x)
            self = .directiveDefinition(x)
        }
    }
    
    case schemaDefinition(SchemaDefinition)
    case typeDefinition(TypeDefinition)
    case directiveDefinition(DirectiveDefinition)
}

public struct SchemaDefinition {
    public let loc: Location?
    public var description: StringValue?
    public var directives: [Directive]
    public var operationTypes: [OperationTypeDefinition]

    init(loc: Location? = nil, description: StringValue? = nil, directives: [Directive], operationTypes: [OperationTypeDefinition]) {
        self.loc = loc
        self.description = description
        self.directives = directives
        self.operationTypes = operationTypes
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.operationTypes)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension SchemaDefinition : Equatable {
    public static func == (lhs: SchemaDefinition, rhs: SchemaDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.directives == rhs.directives &&
            lhs.operationTypes == rhs.operationTypes
    }
}

public struct OperationTypeDefinition {
    public let kind: Kind = .operationDefinition
    public let loc: Location?
    public let operation: OperationType
    public var type: NamedType

    init(loc: Location? = nil, operation: OperationType, type: NamedType) {
        self.loc = loc
        self.operation = operation
        self.type = type
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.type)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension OperationTypeDefinition : Equatable {
    public static func == (lhs: OperationTypeDefinition, rhs: OperationTypeDefinition) -> Bool {
        return lhs.operation == rhs.operation &&
            lhs.type == rhs.type
    }
}

public enum TypeDefinition: EnumNode, Equatable {
    case scalarTypeDefinition(ScalarTypeDefinition)
    case objectTypeDefinition(ObjectTypeDefinition)
    case interfaceTypeDefinition(InterfaceTypeDefinition)
    case unionTypeDefinition(UnionTypeDefinition)
    case enumTypeDefinition(EnumTypeDefinition)
    case inputObjectTypeDefinition(InputObjectTypeDefinition)
    
    fileprivate var underlyingNode: Node {
        switch self {
        case let .scalarTypeDefinition(x):
            return x
        case let .objectTypeDefinition(x):
            return x
        case let .interfaceTypeDefinition(x):
            return x
        case let .unionTypeDefinition(x):
            return x
        case let .enumTypeDefinition(x):
            return x
        case let .inputObjectTypeDefinition(x):
            return x
        }
    }
    
    public mutating func descend(descender: inout Descender) {
        switch self {
        case var .scalarTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .scalarTypeDefinition(x)
        case var .objectTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .objectTypeDefinition(x)
        case var .interfaceTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .interfaceTypeDefinition(x)
        case var .unionTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .unionTypeDefinition(x)
        case var .enumTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .enumTypeDefinition(x)
        case var .inputObjectTypeDefinition(x):
            descender.descend(enumCase: &x)
            self = .inputObjectTypeDefinition(x)
        }
    }
}

public struct ScalarTypeDefinition {
    public let kind: Kind = .scalarTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var directives: [Directive]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.description = description
        self.name = name
        self.directives = directives
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension ScalarTypeDefinition : Equatable {
    public static func == (lhs: ScalarTypeDefinition, rhs: ScalarTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives
    }
}

public struct ObjectTypeDefinition {
    public let kind: Kind = .objectTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var interfaces: [NamedType]
    public var directives: [Directive]
    public var fields: [FieldDefinition]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, interfaces: [NamedType] = [], directives: [Directive] = [], fields: [FieldDefinition] = []) {
        self.loc = loc
        self.description = description
        self.name = name
        self.interfaces = interfaces
        self.directives = directives
        self.fields = fields
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.interfaces)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.fields)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension ObjectTypeDefinition : Equatable {
    public static func == (lhs: ObjectTypeDefinition, rhs: ObjectTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.interfaces == rhs.interfaces &&
            lhs.directives == rhs.directives &&
            lhs.fields == rhs.fields
    }
}

public struct FieldDefinition {
    public let kind: Kind = .fieldDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var arguments: [InputValueDefinition]
    public var type: Type
    public var directives: [Directive]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, arguments: [InputValueDefinition] = [], type: Type, directives: [Directive] = []) {
        self.loc = loc
        self.description = description
        self.name = name
        self.arguments = arguments
        self.type = type
        self.directives = directives
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.arguments)
        descender.descend(&self, \.type)
        descender.descend(&self, \.directives)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension FieldDefinition : Equatable {
    public static func == (lhs: FieldDefinition, rhs: FieldDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.type == rhs.type &&
            lhs.directives == rhs.directives
    }
}

public struct InputValueDefinition {
    public let kind: Kind = .inputValueDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var type: Type
    public var defaultValue: Value?
    public var directives: [Directive]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, type: Type, defaultValue: Value? = nil, directives: [Directive] = []) {
        self.loc = loc
        self.description = description
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.directives = directives
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.type)
        descender.descend(&self, \.defaultValue)
        descender.descend(&self, \.directives)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
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

public struct InterfaceTypeDefinition {
    public let kind: Kind = .interfaceTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var interfaces: [NamedType]
    public var directives: [Directive]
    public var fields: [FieldDefinition]

    init(
        loc: Location? = nil,
        description: StringValue? = nil,
        name: Name,
        interfaces: [NamedType] = [],
        directives: [Directive] = [],
        fields: [FieldDefinition]
    ) {
        self.loc = loc
        self.description = description
        self.name = name
        self.interfaces = interfaces
        self.directives = directives
        self.fields = fields
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.interfaces)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.fields)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension InterfaceTypeDefinition : Equatable {
    public static func == (lhs: InterfaceTypeDefinition, rhs: InterfaceTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.fields == rhs.fields
    }
}

public struct UnionTypeDefinition {
    public let kind: Kind = .unionTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var directives: [Directive]
    public var types: [NamedType]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, directives: [Directive] = [], types: [NamedType]) {
        self.loc = loc
        self.description = description
        self.name = name
        self.directives = directives
        self.types = types
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.types)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension UnionTypeDefinition : Equatable {
    public static func == (lhs: UnionTypeDefinition, rhs: UnionTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.types == rhs.types
    }
}

public struct EnumTypeDefinition {
    public let kind: Kind = .enumTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var directives: [Directive]
    public var values: [EnumValueDefinition]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, directives: [Directive] = [], values: [EnumValueDefinition]) {
        self.loc = loc
        self.description = description
        self.name = name
        self.directives = directives
        self.values = values
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.values)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension EnumTypeDefinition : Equatable {
    public static func == (lhs: EnumTypeDefinition, rhs: EnumTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.values == rhs.values
    }
}

public struct EnumValueDefinition {
    public let kind: Kind = .enumValueDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var directives: [Directive]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, directives: [Directive] = []) {
        self.loc = loc
        self.description = description
        self.name = name
        self.directives = directives
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension EnumValueDefinition : Equatable {
    public static func == (lhs: EnumValueDefinition, rhs: EnumValueDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives
    }
}

public struct InputObjectTypeDefinition {
    public let kind: Kind = .inputObjectTypeDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var directives: [Directive]
    public var fields: [InputValueDefinition]

    init(loc: Location? = nil, description: StringValue? = nil, name: Name, directives: [Directive] = [], fields: [InputValueDefinition]) {
        self.loc = loc
        self.description = description
        self.name = name
        self.directives = directives
        self.fields = fields
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.directives)
        descender.descend(&self, \.fields)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension InputObjectTypeDefinition : Equatable {
    public static func == (lhs: InputObjectTypeDefinition, rhs: InputObjectTypeDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.directives == rhs.directives &&
            lhs.fields == rhs.fields
    }
}

public struct TypeExtensionDefinition {
    public let kind: Kind = .typeExtensionDefinition
    public let loc: Location?
    public var definition: ObjectTypeDefinition

    init(loc: Location? = nil, definition: ObjectTypeDefinition) {
        self.loc = loc
        self.definition = definition
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.definition)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension TypeExtensionDefinition : Equatable {
    public static func == (lhs: TypeExtensionDefinition, rhs: TypeExtensionDefinition) -> Bool {
        return lhs.definition == rhs.definition
    }
}

public struct DirectiveDefinition {
    public let kind: Kind = .directiveDefinition
    public let loc: Location?
    public var description: StringValue?
    public var name: Name
    public var arguments: [InputValueDefinition]
    public var locations: [Name]
    
    init(loc: Location? = nil, description: StringValue? = nil, name: Name, arguments: [InputValueDefinition] = [], locations: [Name]) {
        self.loc = loc
        self.name = name
        self.description = description
        self.arguments = arguments
        self.locations = locations
    }
    
    public mutating func descend(descender: inout Descender) {
        descender.descend(&self, \.description)
        descender.descend(&self, \.name)
        descender.descend(&self, \.arguments)
        descender.descend(&self, \.locations)
    }
    
    public func write<Target>(to target: inout Target) where Target : TextOutputStream {
        fatalError("TODO")
    }
}

extension DirectiveDefinition : Equatable {
    public static func == (lhs: DirectiveDefinition, rhs: DirectiveDefinition) -> Bool {
        return lhs.description == rhs.description &&
            lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.locations == rhs.locations
    }
}
