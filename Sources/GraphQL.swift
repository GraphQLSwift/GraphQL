import CLibgraphqlparser

public final class AST {
    public typealias Node = OpaquePointer

    let node: Node

    init(node: Node) {
        self.node = node
    }

    deinit {
        graphql_node_free(node)
    }

    public var jsonString: String {
        let cString = graphql_ast_to_json(node)
        let string = String(cString: cString!)
        free(UnsafeMutableRawPointer(mutating: cString))
        return string
    }

    public struct Document {
        public let node: Node
    }

    public struct OperationDefinition {
        public let node: Node
    }

    public struct VariableDefinition {
        public let node: Node
    }

    public struct SelectionSet {
        public let node: Node
    }

    public struct Field {
        public let node: Node
    }

    public struct Argument {
        public let node: Node
    }

    public struct FragmentSpread {
        public let node: Node
    }

    public struct InlineFragment {
        public let node: Node
    }

    public struct FragmentDefinition {
        public let node: Node
    }

    public struct Variable {
        public let node: Node
    }

    public struct IntValue {
        public let node: Node
    }

    public struct FloatValue {
        public let node: Node
    }

    public struct StringValue {
        public let node: Node
    }

    public struct BooleanValue {
        public let node: Node
    }

    public struct EnumValue {
        public let node: Node
    }

    public struct ArrayValue {
        public let node: Node
    }

    public struct ObjectValue {
        public let node: Node
    }

    public struct ObjectField {
        public let node: Node
    }

    public struct Directive {
        public let node: Node
    }

    public struct VariableType {
        public let node: Node
    }

    public struct NamedType {
        public let node: Node
    }

    public struct ListType {
        public let node: Node
    }

    public struct NonNullType {
        public let node: Node
    }

    public struct Value {
        public let node: Node
    }

    public struct Name {
        public let node: Node
    }

    public typealias Location = GraphQLAstLocation
}

extension AST.Node {
    var location: AST.Location {
        var loc = AST.Location()
        withUnsafeMutablePointer(to: &loc) {
            graphql_node_get_location(self, $0)
        }
        return loc
    }
}

public extension AST.Document {
    var location: AST.Location {
        return node.location
    }

    var definitionsSize: Int {
        return Int(GraphQLAstDocument_get_definitions_size(node))
    }
}

public extension AST.OperationDefinition {
    var location: AST.Location {
        return node.location
    }

    var operation: String {
        let cString = GraphQLAstOperationDefinition_get_operation(node)
        return String.init(cString: cString!)
    }

    var name: AST.Name? {
        let n = GraphQLAstOperationDefinition_get_name(node)
        return n.flatMap(AST.Name.init(node:))
    }

    var definitionsSize: Int {
        return Int(GraphQLAstOperationDefinition_get_variable_definitions_size(node))
    }

    var directivesSize: Int {
        return Int(GraphQLAstOperationDefinition_get_directives_size(node))
    }

    var selectionSet: AST.SelectionSet {
        let n = GraphQLAstOperationDefinition_get_selection_set(node)
        return AST.SelectionSet(node: n!)
    }
}

public extension AST.VariableDefinition {
    var location: AST.Location {
        return node.location
    }

    var variable: AST.Variable {
        let n = GraphQLAstVariableDefinition_get_variable(node)
        return AST.Variable(node: n!)
    }

    var type: AST.VariableType {
        let n = GraphQLAstVariableDefinition_get_type(node)
        return AST.VariableType(node: n!)
    }

    var value: AST.Value {
        let n = GraphQLAstVariableDefinition_get_default_value(node)
        return AST.Value(node: n!)
    }
}

public extension AST.SelectionSet {
    var location: AST.Location {
        return node.location
    }

    var selectionsSize: Int {
        return Int(GraphQLAstSelectionSet_get_selections_size(node))
    }
}

public extension AST.Field {
    var location: AST.Location {
        return node.location
    }

    var alias: AST.Name? {
        let n = GraphQLAstField_get_alias(node)
        return n.flatMap(AST.Name.init(node:))
    }

    var name: AST.Name {
        let n = GraphQLAstField_get_name(node)
        return AST.Name(node: n!)
    }

    var argumentsSize: Int {
        return Int(GraphQLAstField_get_arguments_size(node))
    }

    var directivesSize: Int {
        return Int(GraphQLAstField_get_directives_size(node))
    }

    var selectionSet: AST.SelectionSet? {
        let n = GraphQLAstField_get_selection_set(node)
        return n.flatMap(AST.SelectionSet.init(node:))
    }
}

public extension AST.Argument {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstArgument_get_name(node)
        return AST.Name(node: n!)
    }

    var value: AST.Value {
        let n = GraphQLAstArgument_get_value(node)
        return AST.Value(node: n!)
    }
}

public extension AST.FragmentSpread {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstFragmentSpread_get_name(node)
        return AST.Name(node: n!)
    }

    var directivesSize: Int {
        return Int(GraphQLAstFragmentSpread_get_directives_size(node))
    }
}

public extension AST.InlineFragment {
    var location: AST.Location {
        return node.location
    }

    var typeCondition: AST.NamedType {
        let n = GraphQLAstInlineFragment_get_type_condition(node)
        return AST.NamedType(node: n!)
    }

    var directivesSize: Int {
        return Int(GraphQLAstInlineFragment_get_directives_size(node))
    }

    var selectionSet: AST.SelectionSet {
        let n = GraphQLAstInlineFragment_get_selection_set(node)
        return AST.SelectionSet(node: n!)
    }
}

public extension AST.FragmentDefinition {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstFragmentDefinition_get_name(node)
        return AST.Name(node: n!)
    }

    var typeCondition: AST.NamedType {
        let n = GraphQLAstFragmentDefinition_get_type_condition(node)
        return AST.NamedType(node: n!)
    }

    var directivesSize: Int {
        return Int(GraphQLAstFragmentDefinition_get_directives_size(node))
    }

    var selectionSet: AST.SelectionSet {
        let n = GraphQLAstFragmentDefinition_get_selection_set(node)
        return AST.SelectionSet(node: n!)
    }
}

public extension AST.Variable {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstVariable_get_name(node)
        return AST.Name(node: n!)
    }
}

public extension AST.IntValue {
    var location: AST.Location {
        return node.location
    }

    var value: String {
        let cString = GraphQLAstIntValue_get_value(node)
        return String.init(cString: cString!)
    }
}

public extension AST.FloatValue {
    var location: AST.Location {
        return node.location
    }

    var value: String {
        let cString = GraphQLAstFloatValue_get_value(node)
        return String.init(cString: cString!)
    }
}

public extension AST.StringValue {
    var location: AST.Location {
        return node.location
    }

    var value: String {
        let cString = GraphQLAstStringValue_get_value(node)
        return String.init(cString: cString!)
    }
}

public extension AST.BooleanValue {
    var location: AST.Location {
        return node.location
    }

    var value: Bool {
        return GraphQLAstBooleanValue_get_value(node) == 0 ? false : true
    }
}

public extension AST.EnumValue {
    var location: AST.Location {
        return node.location
    }

    var value: String {
        let cString = GraphQLAstEnumValue_get_value(node)
        return String.init(cString: cString!)
    }
}

public extension AST.ArrayValue {
    var location: AST.Location {
        return node.location
    }

    var valuesSize: Int {
        return Int(GraphQLAstArrayValue_get_values_size(node))
    }
}

public extension AST.ObjectValue {
    var location: AST.Location {
        return node.location
    }

    var fieldsSize: Int {
        return Int(GraphQLAstObjectValue_get_fields_size(node))
    }
}

public extension AST.ObjectField {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstObjectField_get_name(node)
        return AST.Name(node: n!)
    }

    var value: AST.Value {
        let n = GraphQLAstObjectField_get_value(node)
        return AST.Value(node: n!)
    }
}

public extension AST.Directive {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstDirective_get_name(node)
        return AST.Name(node: n!)
    }

    var argumentsSize: Int {
        return Int(GraphQLAstDirective_get_arguments_size(node))
    }
}

public extension AST.NamedType {
    var location: AST.Location {
        return node.location
    }

    var name: AST.Name {
        let n = GraphQLAstNamedType_get_name(node)
        return AST.Name(node: n!)
    }
}

public extension AST.ListType {
    var location: AST.Location {
        return node.location
    }

    var type: AST.VariableType {
        let n = GraphQLAstListType_get_type(node)
        return AST.VariableType(node: n!)
    }
}

public extension AST.NonNullType {
    var location: AST.Location {
        return node.location
    }

    var type: AST.VariableType {
        let n = GraphQLAstNonNullType_get_type(node)
        return AST.VariableType(node: n!)
    }
}

public extension AST.Name {
    var location: AST.Location {
        return node.location
    }

    var value: String {
        let cString = GraphQLAstName_get_value(node)
        return String.init(cString: cString!)
    }
}

public struct ParserError : Error, CustomStringConvertible {
    public let description: String
}

public struct Parser {
    public static func parse(_ string: String) throws -> AST {
        var error: UnsafePointer<Int8>? = nil

        let node = withUnsafeMutablePointer(to: &error) {
            graphql_parse_string(string, $0)
        }

        guard let n = node else {
            let errorDescription = String(cString: error!)
            graphql_error_free(error)
            throw ParserError(description: errorDescription)
        }

        return AST(node: n)
    }
}

public protocol ParserVisitor {
    func accept(_ ast: AST)
    func visit(document: AST.Document) -> Bool
    func endVisit(document: AST.Document)
    func visit(operationDefinition: AST.OperationDefinition) -> Bool
    func endVisit(operationDefinition: AST.OperationDefinition)
    func visit(variableDefinition: AST.VariableDefinition) -> Bool
    func endVisit(variableDefinition: AST.VariableDefinition)
    func visit(selectionSet: AST.SelectionSet) -> Bool
    func endVisit(selectionSet: AST.SelectionSet)
    func visit(field: AST.Field) -> Bool
    func endVisit(field: AST.Field)
    func visit(argument: AST.Argument) -> Bool
    func endVisit(argument: AST.Argument)
    func visit(fragmentSpread: AST.FragmentSpread) -> Bool
    func endVisit(fragmentSpread: AST.FragmentSpread)
    func visit(inlineFragment: AST.InlineFragment) -> Bool
    func endVisit(inlineFragment: AST.InlineFragment)
    func visit(fragmentDefinition: AST.FragmentDefinition) -> Bool
    func endVisit(fragmentDefinition: AST.FragmentDefinition)
    func visit(variable: AST.Variable) -> Bool
    func endVisit(variable: AST.Variable)
    func visit(intValue: AST.IntValue) -> Bool
    func endVisit(intValue: AST.IntValue)
    func visit(floatValue: AST.FloatValue) -> Bool
    func endVisit(floatValue: AST.FloatValue)
    func visit(stringValue: AST.StringValue) -> Bool
    func endVisit(stringValue: AST.StringValue)
    func visit(booleanValue: AST.BooleanValue) -> Bool
    func endVisit(booleanValue: AST.BooleanValue)
    func visit(enumValue: AST.EnumValue) -> Bool
    func endVisit(enumValue: AST.EnumValue)
    func visit(arrayValue: AST.ArrayValue) -> Bool
    func endVisit(arrayValue: AST.ArrayValue)
    func visit(objectValue: AST.ObjectValue) -> Bool
    func endVisit(objectValue: AST.ObjectValue)
    func visit(objectField: AST.ObjectField) -> Bool
    func endVisit(objectField: AST.ObjectField)
    func visit(directive: AST.Directive) -> Bool
    func endVisit(directive: AST.Directive)
    func visit(namedType: AST.NamedType) -> Bool
    func endVisit(namedType: AST.NamedType)
    func visit(listType: AST.ListType) -> Bool
    func endVisit(listType: AST.ListType)
    func visit(nonNullType: AST.NonNullType) -> Bool
    func endVisit(nonNullType: AST.NonNullType)
    func visit(name: AST.Name) -> Bool
    func endVisit(name: AST.Name)
}

public extension ParserVisitor {
    func accept(_ ast: AST) {
        var input = VisitorBox(visitor: self)

        withUnsafePointer(to: &callbacks) { cb in
            withUnsafeMutablePointer(to: &input) { ud in
                graphql_node_visit(ast.node, cb, ud)
            }
        }
    }

    func visit(document: AST.Document) -> Bool { return false }
    func endVisit(document: AST.Document) {}
    func visit(operationDefinition: AST.OperationDefinition) -> Bool { return false }
    func endVisit(operationDefinition: AST.OperationDefinition) {}
    func visit(variableDefinition: AST.VariableDefinition) -> Bool { return false }
    func endVisit(variableDefinition: AST.VariableDefinition) {}
    func visit(selectionSet: AST.SelectionSet) -> Bool { return false }
    func endVisit(selectionSet: AST.SelectionSet) {}
    func visit(field: AST.Field) -> Bool { return false }
    func endVisit(field: AST.Field) {}
    func visit(argument: AST.Argument) -> Bool { return false }
    func endVisit(argument: AST.Argument) {}
    func visit(fragmentSpread: AST.FragmentSpread) -> Bool { return false }
    func endVisit(fragmentSpread: AST.FragmentSpread) {}
    func visit(inlineFragment: AST.InlineFragment) -> Bool { return false }
    func endVisit(inlineFragment: AST.InlineFragment) {}
    func visit(fragmentDefinition: AST.FragmentDefinition) -> Bool { return false }
    func endVisit(fragmentDefinition: AST.FragmentDefinition) {}
    func visit(variable: AST.Variable) -> Bool { return false }
    func endVisit(variable: AST.Variable) {}
    func visit(intValue: AST.IntValue) -> Bool { return false }
    func endVisit(intValue: AST.IntValue) {}
    func visit(floatValue: AST.FloatValue) -> Bool { return false }
    func endVisit(floatValue: AST.FloatValue) {}
    func visit(stringValue: AST.StringValue) -> Bool { return false }
    func endVisit(stringValue: AST.StringValue) {}
    func visit(booleanValue: AST.BooleanValue) -> Bool { return false }
    func endVisit(booleanValue: AST.BooleanValue) {}
    func visit(enumValue: AST.EnumValue) -> Bool { return false }
    func endVisit(enumValue: AST.EnumValue) {}
    func visit(arrayValue: AST.ArrayValue) -> Bool { return false }
    func endVisit(arrayValue: AST.ArrayValue) {}
    func visit(objectValue: AST.ObjectValue) -> Bool { return false }
    func endVisit(objectValue: AST.ObjectValue) {}
    func visit(objectField: AST.ObjectField) -> Bool { return false }
    func endVisit(objectField: AST.ObjectField) {}
    func visit(directive: AST.Directive) -> Bool { return false }
    func endVisit(directive: AST.Directive) {}
    func visit(namedType: AST.NamedType) -> Bool { return false }
    func endVisit(namedType: AST.NamedType) {}
    func visit(listType: AST.ListType) -> Bool { return false }
    func endVisit(listType: AST.ListType) {}
    func visit(nonNullType: AST.NonNullType) -> Bool { return false }
    func endVisit(nonNullType: AST.NonNullType) {}
    func visit(name: AST.Name) -> Bool { return false }
    func endVisit(name: AST.Name) {}
}

final class VisitorBox {
    let visitor: ParserVisitor

    public init(visitor: ParserVisitor) {
        self.visitor = visitor
    }
}

func visitDocument(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(document: AST.Document(node: node!)) ? 1 : 0
}

func endVisitDocument(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(document: AST.Document(node: node!))
}

func visitOperationDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(operationDefinition: AST.OperationDefinition(node: node!)) ? 1 : 0
}

func endVisitOperationDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(operationDefinition: AST.OperationDefinition(node: node!))
}

func visitVariableDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(variableDefinition: AST.VariableDefinition(node: node!)) ? 1 : 0
}

func endVisitVariableDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(variableDefinition: AST.VariableDefinition(node: node!))
}

func visitSelectionSet(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(selectionSet: AST.SelectionSet(node: node!)) ? 1 : 0
}

func endVisitSelectionSet(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(selectionSet: AST.SelectionSet(node: node!))
}

func visitField(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(field: AST.Field(node: node!)) ? 1 : 0
}

func endVisitField(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(field: AST.Field(node: node!))
}

func visitArgument(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(argument: AST.Argument(node: node!)) ? 1 : 0
}

func endVisitArgument(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(argument: AST.Argument(node: node!))
}

func visitFragmentSpread(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(fragmentSpread: AST.FragmentSpread(node: node!)) ? 1 : 0
}

func endVisitFragmentSpread(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(fragmentSpread: AST.FragmentSpread(node: node!))
}

func visitInlineFragment(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(inlineFragment: AST.InlineFragment(node: node!)) ? 1 : 0
}

func endVisitInlineFragment(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(inlineFragment: AST.InlineFragment(node: node!))
}

func visitFragmentDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(fragmentDefinition: AST.FragmentDefinition(node: node!)) ? 1 : 0
}

func endVisitFragmentDefinition(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(fragmentDefinition: AST.FragmentDefinition(node: node!))
}

func visitVariable(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(variable: AST.Variable(node: node!)) ? 1 : 0
}

func endVisitVariable(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(variable: AST.Variable(node: node!))
}

func visitIntValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(intValue: AST.IntValue(node: node!)) ? 1 : 0
}

func endVisitIntValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(intValue: AST.IntValue(node: node!))
}

func visitFloatValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(floatValue: AST.FloatValue(node: node!)) ? 1 : 0
}

func endVisitFloatValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(floatValue: AST.FloatValue(node: node!))
}

func visitStringValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(stringValue: AST.StringValue(node: node!)) ? 1 : 0
}

func endVisitStringValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(stringValue: AST.StringValue(node: node!))
}

func visitBooleanValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(booleanValue: AST.BooleanValue(node: node!)) ? 1 : 0
}

func endVisitBooleanValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(booleanValue: AST.BooleanValue(node: node!))
}

func visitEnumValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(enumValue: AST.EnumValue(node: node!)) ? 1 : 0
}

func endVisitEnumValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(enumValue: AST.EnumValue(node: node!))
}

func visitArrayValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(arrayValue: AST.ArrayValue(node: node!)) ? 1 : 0
}

func endVisitArrayValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(arrayValue: AST.ArrayValue(node: node!))
}

func visitObjectValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(objectValue: AST.ObjectValue(node: node!)) ? 1 : 0
}

func endVisitObjectValue(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(objectValue: AST.ObjectValue(node: node!))
}

func visitObjectField(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(objectField: AST.ObjectField(node: node!)) ? 1 : 0
}

func endVisitObjectField(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(objectField: AST.ObjectField(node: node!))
}

func visitDirective(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(directive: AST.Directive(node: node!)) ? 1 : 0
}

func endVisitDirective(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(directive: AST.Directive(node: node!))
}

func visitNamedType(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(namedType: AST.NamedType(node: node!)) ? 1 : 0
}

func endVisitNamedType(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(namedType: AST.NamedType(node: node!))
}

func visitListType(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(listType: AST.ListType(node: node!)) ? 1 : 0
}

func endVisitListType(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(listType: AST.ListType(node: node!))
}

func visitNonNullType(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(nonNullType: AST.NonNullType(node: node!)) ? 1 : 0
}

func endVisitNonNullType(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(nonNullType: AST.NonNullType(node: node!))
}

func visitName(node: AST.Node?, userData: UnsafeMutableRawPointer?) -> Int32 {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    return visitor.visit(name: AST.Name(node: node!)) ? 1 : 0
}

func endVisitName(node: AST.Node?, userData: UnsafeMutableRawPointer?) {
    let visitor = userData!.assumingMemoryBound(to: VisitorBox.self).pointee.visitor
    visitor.endVisit(name: AST.Name(node: node!))
}

var callbacks = GraphQLAstVisitorCallbacks(
    visit_document: visitDocument,
    end_visit_document: endVisitDocument,
    visit_operation_definition: visitOperationDefinition,
    end_visit_operation_definition: endVisitOperationDefinition,
    visit_variable_definition: visitVariableDefinition,
    end_visit_variable_definition: endVisitVariableDefinition,
    visit_selection_set: visitSelectionSet,
    end_visit_selection_set: endVisitSelectionSet,
    visit_field: visitField,
    end_visit_field: endVisitField,
    visit_argument: visitArgument,
    end_visit_argument: endVisitArgument,
    visit_fragment_spread: visitFragmentSpread,
    end_visit_fragment_spread: endVisitFragmentSpread,
    visit_inline_fragment: visitInlineFragment,
    end_visit_inline_fragment: endVisitInlineFragment,
    visit_fragment_definition: visitFragmentDefinition,
    end_visit_fragment_definition: endVisitFragmentDefinition,
    visit_variable: visitVariable,
    end_visit_variable: endVisitVariable,
    visit_int_value: visitIntValue,
    end_visit_int_value: endVisitIntValue,
    visit_float_value: visitFloatValue,
    end_visit_float_value: endVisitFloatValue,
    visit_string_value: visitStringValue,
    end_visit_string_value: endVisitStringValue,
    visit_boolean_value: visitBooleanValue,
    end_visit_boolean_value: endVisitBooleanValue,
    visit_enum_value: visitEnumValue,
    end_visit_enum_value: endVisitEnumValue,
    visit_array_value: visitArrayValue,
    end_visit_array_value: endVisitArrayValue,
    visit_object_value: visitObjectValue,
    end_visit_object_value: endVisitObjectValue,
    visit_object_field: visitObjectField,
    end_visit_object_field: endVisitObjectField,
    visit_directive: visitDirective,
    end_visit_directive: endVisitDirective,
    visit_named_type: visitNamedType,
    end_visit_named_type: endVisitNamedType,
    visit_list_type: visitListType,
    end_visit_list_type: endVisitListType,
    visit_non_null_type: visitNonNullType,
    end_visit_non_null_type: endVisitNonNullType,
    visit_name: visitName,
    end_visit_name: endVisitName
)
