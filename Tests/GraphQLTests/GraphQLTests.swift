import XCTest
@testable import GraphQL

final class Visitor : ParserVisitor {
    func visit(document: AST.Document) -> Bool {
        print(document.definitionsSize)
        return true
    }

    func endVisit(document: AST.Document) {
        print(document.definitionsSize)
    }

    func visit(operationDefinition: AST.OperationDefinition) -> Bool {
        print(operationDefinition.name?.value)
        print(operationDefinition.operation)
        print(operationDefinition.selectionSet.selectionsSize)
        print(operationDefinition.directivesSize)
        print(operationDefinition.definitionsSize)
        return true
    }

    func endVisit(operationDefinition: AST.OperationDefinition) {
        print(operationDefinition.name?.value)
        print(operationDefinition.operation)
        print(operationDefinition.selectionSet.selectionsSize)
        print(operationDefinition.directivesSize)
        print(operationDefinition.definitionsSize)
    }

    func visit(variableDefinition: AST.VariableDefinition) -> Bool {
        print(variableDefinition.type)
        print(variableDefinition.value)
        print(variableDefinition.variable.name.value)
        return true
    }

    func endVisit(variableDefinition: AST.VariableDefinition) {
        print(variableDefinition.type)
        print(variableDefinition.value)
        print(variableDefinition.variable.name.value)
    }

    func visit(selectionSet: AST.SelectionSet) -> Bool {
        print(selectionSet.selectionsSize)
        return true
    }

    func endVisit(selectionSet: AST.SelectionSet) {
        print(selectionSet.selectionsSize)
    }

    func visit(field: AST.Field) -> Bool {
        print(field.alias?.value)
        print(field.name.value)
        print(field.argumentsSize)
        print(field.directivesSize)
        print(field.selectionSet?.selectionsSize)
        return true
    }

    func endVisit(field: AST.Field) {
        print(field.alias?.value)
        print(field.name.value)
        print(field.argumentsSize)
        print(field.directivesSize)
        print(field.selectionSet?.selectionsSize)
    }

    func visit(argument: AST.Argument) -> Bool {
        print(argument.name.value)
        print(argument.value)
        return true
    }

    func endVisit(argument: AST.Argument) {
        print(argument.name.value)
        print(argument.value)
    }

    func visit(fragmentSpread: AST.FragmentSpread) -> Bool {
        print(fragmentSpread.name.value)
        print(fragmentSpread.directivesSize)
        return true
    }

    func endVisit(fragmentSpread: AST.FragmentSpread) {
        print(fragmentSpread.name.value)
        print(fragmentSpread.directivesSize)
    }

    func visit(inlineFragment: AST.InlineFragment) -> Bool {
        print(inlineFragment.directivesSize)
        print(inlineFragment.selectionSet.selectionsSize)
        print(inlineFragment.typeCondition.name.value)
        return true
    }

    func endVisit(inlineFragment: AST.InlineFragment) {
        print(inlineFragment.directivesSize)
        print(inlineFragment.selectionSet.selectionsSize)
        print(inlineFragment.typeCondition.name.value)
    }

    func visit(fragmentDefinition: AST.FragmentDefinition) -> Bool {
        print(fragmentDefinition.name.value)
        print(fragmentDefinition.directivesSize)
        print(fragmentDefinition.selectionSet.selectionsSize)
        print(fragmentDefinition.typeCondition.name.value)
        return true
    }

    func endVisit(fragmentDefinition: AST.FragmentDefinition) {
        print(fragmentDefinition.name.value)
        print(fragmentDefinition.directivesSize)
        print(fragmentDefinition.selectionSet.selectionsSize)
        print(fragmentDefinition.typeCondition.name.value)
    }

    func visit(variable: AST.Variable) -> Bool {
        print(variable.name.value)
        return true
    }

    func endVisit(variable: AST.Variable) {
        print(variable.name.value)
    }

    func visit(intValue: AST.IntValue) -> Bool {
        print(intValue.value)
        return true
    }

    func endVisit(intValue: AST.IntValue) {
        print(intValue.value)
    }

    func visit(floatValue: AST.FloatValue) -> Bool {
        print(floatValue.value)
        return true
    }

    func endVisit(floatValue: AST.FloatValue) {
        print(floatValue.value)
    }

    func visit(stringValue: AST.StringValue) -> Bool {
        print(stringValue.value)
        return true
    }

    func endVisit(stringValue: AST.StringValue) {
        print(stringValue.value)
    }

    func visit(booleanValue: AST.BooleanValue) -> Bool {
        print(booleanValue.value)
        return true
    }

    func endVisit(booleanValue: AST.BooleanValue) {
        print(booleanValue.value)
    }

    func visit(enumValue: AST.EnumValue) -> Bool {
        print(enumValue.value)
        return true
    }

    func endVisit(enumValue: AST.EnumValue) {
        print(enumValue.value)
    }

    func visit(arrayValue: AST.ArrayValue) -> Bool {
        print(arrayValue.valuesSize)
        return true
    }

    func endVisit(arrayValue: AST.ArrayValue) {
        print(arrayValue.valuesSize)
    }

    func visit(objectValue: AST.ObjectValue) -> Bool {
        print(objectValue.fieldsSize)
        return true
    }

    func endVisit(objectValue: AST.ObjectValue) {
        print(objectValue.fieldsSize)
    }

    func visit(objectField: AST.ObjectField) -> Bool {
        print(objectField.name.value)
        print(objectField.value)
        return true
    }

    func endVisit(objectField: AST.ObjectField) {
        print(objectField.name.value)
        print(objectField.value)
    }

    func visit(directive: AST.Directive) -> Bool {
        print(directive.name.value)
        print(directive.argumentsSize)
        return true
    }

    func endVisit(directive: AST.Directive) {
        print(directive.name.value)
        print(directive.argumentsSize)
    }

    func visit(namedType: AST.NamedType) -> Bool {
        print(namedType.name.value)
        return true
    }

    func endVisit(namedType: AST.NamedType) {
        print(namedType.name.value)
    }

    func visit(listType: AST.ListType) -> Bool {
        print(listType.type)
        return true
    }

    func endVisit(listType: AST.ListType) {
        print(listType.type)
    }

    func visit(nonNullType: AST.NonNullType) -> Bool {
        print(nonNullType.type)
        return true
    }

    func endVisit(nonNullType: AST.NonNullType) {
        print(nonNullType.type)
    }
    
    func visit(name: AST.Name) -> Bool {
        print(name.value)
        return true
    }
    
    func endVisit(name: AST.Name) {
        print(name.value)
    }
}

class GraphQLTests: XCTestCase {
    func testSimple() throws {
        let ast = try Parser.parse("{ foo(bar:\"baz\") }")
        print(ast.jsonString)
        let visitor = Visitor()
        visitor.accept(ast)
    }
}

extension GraphQLTests {
    static var allTests: [(String, (GraphQLTests) -> () throws -> Void)] {
        return [
            ("testSimple", testSimple),
        ]
    }
}
