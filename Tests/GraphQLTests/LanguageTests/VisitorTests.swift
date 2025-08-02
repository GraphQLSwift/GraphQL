@testable import GraphQL
import XCTest

class VisitorTests: XCTestCase {
    func testHandlesEmptyVisitor() throws {
        let ast = try parse(source: "{ a }", noLocation: true)
        XCTAssertNoThrow(visit(root: ast, visitor: .init()))
    }

    func testValidatesPathArgument() throws {
        var visited = [VisitedPath]()
        let ast = try parse(source: "{ a }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.enter, path))
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.leave, path))
                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, []),
                .init(.enter, ["definitions", 0]),
                .init(.enter, ["definitions", 0, "selectionSet"]),
                .init(.enter, ["definitions", 0, "selectionSet", "selections", 0]),
                .init(.enter, ["definitions", 0, "selectionSet", "selections", 0, "name"]),
                .init(.leave, ["definitions", 0, "selectionSet", "selections", 0, "name"]),
                .init(.leave, ["definitions", 0, "selectionSet", "selections", 0]),
                .init(.leave, ["definitions", 0, "selectionSet"]),
                .init(.leave, ["definitions", 0]),
                .init(.leave, []),
            ]
        )
    }

    func testValidatesAncestorsArgument() throws {
        var visited = [NodeResult]()
        let ast = try parse(source: "{ a }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, _, parent, _, ancestors in
                if let parent = parent, parent.isArray {
                    visited.append(parent)
                }
                visited.append(.node(node))

                let expectedAncestors = visited[0 ... max(visited.count - 2, 0)]
                XCTAssert(zip(ancestors, expectedAncestors).allSatisfy { lhs, rhs in
                    nodeResultsEqual(lhs, rhs)
                }, "actual: \(ancestors), expected: \(expectedAncestors)")
                return .continue
            },
            leave: { _, _, parent, _, ancestors in
                let expectedAncestors = visited[0 ... max(visited.count - 2, 0)]
                XCTAssert(zip(ancestors, expectedAncestors).allSatisfy { lhs, rhs in
                    nodeResultsEqual(lhs, rhs)
                }, "actual: \(ancestors), expected: \(expectedAncestors)")

                if let parent = parent, parent.isArray {
                    visited.removeLast()
                }
                visited.removeLast()

                return .continue
            }
        ))
    }

    func testAllowsEditingANodeBothOnEnterAndOnLeave() throws {
        let ast = try parse(source: "{ a, b, c { a, b, c } }", noLocation: true)

        var selectionSet: SelectionSet? = nil

        let editedASTNode = visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                if let node = node as? OperationDefinition {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    selectionSet = node.selectionSet
                    let newName = node.name
                        .map { Name(loc: $0.loc, value: $0.value + ".enter") } ??
                        Name(value: "enter")
                    let newNode = node
                        .set(value: .node(newName), key: "name")
                        .set(value: .node(SelectionSet(selections: [])), key: "selectionSet")
                    return .node(newNode)
                }
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                if let node = node as? OperationDefinition {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors, isEdited: true)
                    let newName = node.name
                        .map { Name(loc: $0.loc, value: $0.value + ".leave") } ??
                        Name(value: "leave")
                    let newNode = node
                        .set(value: .node(newName), key: "name")
                        .set(value: .node(selectionSet!), key: "selectionSet")
                    return .node(newNode)
                }
                return .continue
            }
        ))

        let editedAST = try XCTUnwrap(editedASTNode as? Document)
        let operations = try XCTUnwrap(editedAST.definitions as? [OperationDefinition])
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations.first?.name?.value, "enter.leave")
        let operationSelections = try XCTUnwrap(operations.first?.selectionSet.selections)
        XCTAssertEqual(operationSelections.count, 3)
    }

    func testAllowsEditingTheRootNodeOnEnterAndOnLeave() throws {
        let ast = try parse(source: "{ a, b, c { a, b, c } }", noLocation: true)

        let editedASTNode = visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                if let node = node as? Document {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    var newDefinitions = node.definitions
                    newDefinitions.append(
                        DirectiveDefinition(
                            name: .init(value: "enter"),
                            locations: [.init(value: "root")]
                        )
                    )
                    let newNode = node.set(
                        value: .array(newDefinitions),
                        key: "definitions"
                    )
                    return .node(newNode)
                }
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                if let node = node as? Document {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors, isEdited: true)
                    var newDefinitions = node.definitions
                    newDefinitions.append(
                        DirectiveDefinition(
                            name: .init(value: "leave"),
                            locations: [.init(value: "root")]
                        )
                    )
                    let newNode = node.set(
                        value: .array(newDefinitions),
                        key: "definitions"
                    )
                    return .node(newNode)
                }
                return .continue
            }
        ))

        let editedAST = try XCTUnwrap(editedASTNode as? Document)
        XCTAssertEqual(editedAST.definitions.count, 3)
        try XCTAssertEqual(
            XCTUnwrap(editedAST.definitions[1] as? DirectiveDefinition).name.value,
            "enter"
        )
        try XCTAssertEqual(
            XCTUnwrap(editedAST.definitions[2] as? DirectiveDefinition).name.value,
            "leave"
        )
    }

    func testAllowsForEditingOnEnter() throws {
        let ast = try parse(source: "{ a, b, c { a, b, c } }", noLocation: true)

        let editedASTNode = visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                if let node = node as? Field {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    if node.name.value == "b" {
                        return .node(nil)
                    }
                }
                return .continue
            }
        ))

        let editedAST = try XCTUnwrap(editedASTNode as? Document)
        let operation = try XCTUnwrap(editedAST.definitions[0] as? OperationDefinition)
        XCTAssertEqual(
            operation.selectionSet.selections.count,
            2 // "b" is ignored
        )

        let cField = try XCTUnwrap(operation.selectionSet.selections[1] as? Field)
        XCTAssertEqual(
            cField.selectionSet?.selections.count,
            2 // "b" is ignored
        )
    }

    func testAllowsForEditingOnLeave() throws {
        let ast = try parse(source: "{ a, b, c { a, b, c } }", noLocation: true)

        let editedASTNode = visit(root: ast, visitor: .init(
            leave: { node, key, parent, path, ancestors in
                if let node = node as? Field {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    if node.name.value == "b" {
                        return .node(nil)
                    }
                }
                return .continue
            }
        ))

        let editedAST = try XCTUnwrap(editedASTNode as? Document)
        let operation = try XCTUnwrap(editedAST.definitions[0] as? OperationDefinition)
        XCTAssertEqual(
            operation.selectionSet.selections.count,
            2 // "b" is removed
        )

        let cField = try XCTUnwrap(operation.selectionSet.selections[1] as? Field)
        XCTAssertEqual(
            cField.selectionSet?.selections.count,
            2 // "b" is removed
        )
    }

    func testIgnoresSkipReturnedOnLeave() throws {
        let ast = try parse(source: "{ a, b, c { a, b, c } }", noLocation: true)

        let editedASTNode = visit(root: ast, visitor: .init(
            leave: { _, _, _, _, _ in
                .skip // graphql-js 'false' is Swift '.skip'
            }
        ))

        let editedAST = try XCTUnwrap(editedASTNode as? Document)
        let operation = try XCTUnwrap(editedAST.definitions[0] as? OperationDefinition)
        XCTAssertEqual(
            operation.selectionSet.selections.count,
            3 // "b" remains
        )

        let cField = try XCTUnwrap(operation.selectionSet.selections[2] as? Field)
        XCTAssertEqual(
            cField.selectionSet?.selections.count,
            3 // "b" remains
        )
    }

    func testVisitsEditedNode() throws {
        let addedField = Field(
            name: Name(value: "__typename")
        )

        var didVisitAddedField = false

        let ast = try parse(source: "{ a { x } }", noLocation: true)
        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors, isEdited: true)
                if let node = node as? Field, node.name.value == "a" {
                    if let selectionSet = node.selectionSet {
                        var newSelections = selectionSet.selections
                        newSelections.append(addedField)

                        var newSelectionSet = selectionSet
                        newSelectionSet = newSelectionSet.set(
                            value: .array(newSelections),
                            key: "selections"
                        )

                        let newNode = node.set(value: .node(newSelectionSet), key: "selectionSet")
                        return .node(newNode)
                    }
                }
                if let node = node as? Field, node.name.value == "__typename" {
                    didVisitAddedField = true
                }
                return .continue
            }
        ))

        XCTAssert(didVisitAddedField)
    }

    func testAllowsSkippingASubTree() throws {
        struct VisitedElement: Equatable {
            let direction: VisitDirection
            let kind: Kind
            let value: String?

            init(_ direction: VisitDirection, _ kind: Kind, _ value: String?) {
                self.direction = direction
                self.kind = kind
                self.value = value
            }
        }

        var visited = [VisitedElement]()
        let ast = try parse(source: "{ a, b { x }, c }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.enter, node.kind, getValue(node: node)))
                if let node = node as? Field, node.name.value == "b" {
                    return .skip
                }
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.leave, node.kind, getValue(node: node)))
                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, .document, nil),
                .init(.enter, .operationDefinition, nil),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "a"),
                .init(.leave, .name, "a"),
                .init(.leave, .field, nil),
                .init(.enter, .field, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "c"),
                .init(.leave, .name, "c"),
                .init(.leave, .field, nil),
                .init(.leave, .selectionSet, nil),
                .init(.leave, .operationDefinition, nil),
                .init(.leave, .document, nil),
            ]
        )
    }

    func testAllowsEarlyExitWhileVisiting() throws {
        struct VisitedElement: Equatable {
            let direction: VisitDirection
            let kind: Kind
            let value: String?

            init(_ direction: VisitDirection, _ kind: Kind, _ value: String?) {
                self.direction = direction
                self.kind = kind
                self.value = value
            }
        }

        var visited = [VisitedElement]()
        let ast = try parse(source: "{ a, b { x }, c }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.enter, node.kind, getValue(node: node)))
                if let node = node as? Name, node.value == "x" {
                    return .break
                }
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.leave, node.kind, getValue(node: node)))
                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, .document, nil),
                .init(.enter, .operationDefinition, nil),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "a"),
                .init(.leave, .name, "a"),
                .init(.leave, .field, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "b"),
                .init(.leave, .name, "b"),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "x"),
            ]
        )
    }

    func testAllowsEarlyExitWhileLeaving() throws {
        struct VisitedElement: Equatable {
            let direction: VisitDirection
            let kind: Kind
            let value: String?

            init(_ direction: VisitDirection, _ kind: Kind, _ value: String?) {
                self.direction = direction
                self.kind = kind
                self.value = value
            }
        }

        var visited = [VisitedElement]()
        let ast = try parse(source: "{ a, b { x }, c }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.enter, node.kind, getValue(node: node)))
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                visited.append(.init(.leave, node.kind, getValue(node: node)))
                if let node = node as? Name, node.value == "x" {
                    return .break
                }
                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, .document, nil),
                .init(.enter, .operationDefinition, nil),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "a"),
                .init(.leave, .name, "a"),
                .init(.leave, .field, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "b"),
                .init(.leave, .name, "b"),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .field, nil),
                .init(.enter, .name, "x"),
                .init(.leave, .name, "x"),
            ]
        )
    }

    func testAllowsANamedFunctionsVisitorAPI() throws {
        struct VisitedElement: Equatable {
            let direction: VisitDirection
            let kind: Kind
            let value: String?

            init(_ direction: VisitDirection, _ kind: Kind, _ value: String?) {
                self.direction = direction
                self.kind = kind
                self.value = value
            }
        }

        var visited = [VisitedElement]()
        let ast = try parse(source: "{ a, b { x }, c }", noLocation: true)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, path, ancestors in
                if let node = node as? Name {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    visited.append(.init(.enter, node.kind, getValue(node: node)))
                }
                if let node = node as? SelectionSet {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    visited.append(.init(.enter, node.kind, getValue(node: node)))
                }
                return .continue
            },
            leave: { node, key, parent, path, ancestors in
                if let node = node as? SelectionSet {
                    checkVisitorFnArgs(ast, node, key, parent, path, ancestors)
                    visited.append(.init(.leave, node.kind, getValue(node: node)))
                }
                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, .selectionSet, nil),
                .init(.enter, .name, "a"),
                .init(.enter, .name, "b"),
                .init(.enter, .selectionSet, nil),
                .init(.enter, .name, "x"),
                .init(.leave, .selectionSet, nil),
                .init(.enter, .name, "c"),
                .init(.leave, .selectionSet, nil),
            ]
        )
    }

    func testProperlyVisitsTheKitchenSinkQuery() throws {
        var visited = [VisitedKindAndParent]()

        guard
            let url = Bundle.module.url(forResource: "kitchen-sink", withExtension: "graphql"),
            let kitchenSink = try? String(contentsOf: url)
        else {
            XCTFail("Could not load kitchen sink")
            return
        }
        let ast = try parse(source: kitchenSink)

        visit(root: ast, visitor: .init(
            enter: { node, key, parent, _, _ in
                var parentKind: Kind?
                if case let .node(parent) = parent {
                    parentKind = parent.kind
                }
                visited.append(.init(.enter, node.kind, key, parentKind))
                return .continue
            },
            leave: { node, key, parent, _, _ in
                var parentKind: Kind?
                if case let .node(parent) = parent {
                    parentKind = parent.kind
                }
                visited.append(.init(.leave, node.kind, key, parentKind))

                return .continue
            }
        ))

        XCTAssertEqual(
            visited,
            [
                .init(.enter, .document, nil, nil),
                .init(.enter, .operationDefinition, 0, nil),
                .init(.enter, .name, "name", .operationDefinition),
                .init(.leave, .name, "name", .operationDefinition),
                .init(.enter, .variableDefinition, 0, nil),
                .init(.enter, .variable, "variable", .variableDefinition),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "variable", .variableDefinition),
                .init(.enter, .namedType, "type", .variableDefinition),
                .init(.enter, .name, "name", .namedType),
                .init(.leave, .name, "name", .namedType),
                .init(.leave, .namedType, "type", .variableDefinition),
                .init(.leave, .variableDefinition, 0, nil),
                .init(.enter, .variableDefinition, 1, nil),
                .init(.enter, .variable, "variable", .variableDefinition),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "variable", .variableDefinition),
                .init(.enter, .namedType, "type", .variableDefinition),
                .init(.enter, .name, "name", .namedType),
                .init(.leave, .name, "name", .namedType),
                .init(.leave, .namedType, "type", .variableDefinition),
                .init(.enter, .enumValue, "defaultValue", .variableDefinition),
                .init(.leave, .enumValue, "defaultValue", .variableDefinition),
                .init(.leave, .variableDefinition, 1, nil),
                .init(.enter, .selectionSet, "selectionSet", .operationDefinition),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "alias", .field),
                .init(.leave, .name, "alias", .field),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .listValue, "value", .argument),
                .init(.enter, .intValue, 0, nil),
                .init(.leave, .intValue, 0, nil),
                .init(.enter, .intValue, 1, nil),
                .init(.leave, .intValue, 1, nil),
                .init(.leave, .listValue, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.enter, .inlineFragment, 1, nil),
                .init(.enter, .namedType, "typeCondition", .inlineFragment),
                .init(.enter, .name, "name", .namedType),
                .init(.leave, .name, "name", .namedType),
                .init(.leave, .namedType, "typeCondition", .inlineFragment),
                .init(.enter, .directive, 0, nil),
                .init(.enter, .name, "name", .directive),
                .init(.leave, .name, "name", .directive),
                .init(.leave, .directive, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .inlineFragment),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.enter, .field, 1, nil),
                .init(.enter, .name, "alias", .field),
                .init(.leave, .name, "alias", .field),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .intValue, "value", .argument),
                .init(.leave, .intValue, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .argument, 1, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 1, nil),
                .init(.enter, .directive, 0, nil),
                .init(.enter, .name, "name", .directive),
                .init(.leave, .name, "name", .directive),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.leave, .directive, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.enter, .fragmentSpread, 1, nil),
                .init(.enter, .name, "name", .fragmentSpread),
                .init(.leave, .name, "name", .fragmentSpread),
                .init(.leave, .fragmentSpread, 1, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 1, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .inlineFragment),
                .init(.leave, .inlineFragment, 1, nil),
                .init(.enter, .inlineFragment, 2, nil),
                .init(.enter, .directive, 0, nil),
                .init(.enter, .name, "name", .directive),
                .init(.leave, .name, "name", .directive),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.leave, .directive, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .inlineFragment),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .inlineFragment),
                .init(.leave, .inlineFragment, 2, nil),
                .init(.enter, .inlineFragment, 3, nil),
                .init(.enter, .selectionSet, "selectionSet", .inlineFragment),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .inlineFragment),
                .init(.leave, .inlineFragment, 3, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .operationDefinition),
                .init(.leave, .operationDefinition, 0, nil),
                .init(.enter, .operationDefinition, 1, nil),
                .init(.enter, .name, "name", .operationDefinition),
                .init(.leave, .name, "name", .operationDefinition),
                .init(.enter, .selectionSet, "selectionSet", .operationDefinition),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .intValue, "value", .argument),
                .init(.leave, .intValue, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .directive, 0, nil),
                .init(.enter, .name, "name", .directive),
                .init(.leave, .name, "name", .directive),
                .init(.leave, .directive, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .operationDefinition),
                .init(.leave, .operationDefinition, 1, nil),
                .init(.enter, .operationDefinition, 2, nil),
                .init(.enter, .name, "name", .operationDefinition),
                .init(.leave, .name, "name", .operationDefinition),
                .init(.enter, .variableDefinition, 0, nil),
                .init(.enter, .variable, "variable", .variableDefinition),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "variable", .variableDefinition),
                .init(.enter, .namedType, "type", .variableDefinition),
                .init(.enter, .name, "name", .namedType),
                .init(.leave, .name, "name", .namedType),
                .init(.leave, .namedType, "type", .variableDefinition),
                .init(.leave, .variableDefinition, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .operationDefinition),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.enter, .field, 1, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .selectionSet, "selectionSet", .field),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 1, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .field),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .operationDefinition),
                .init(.leave, .operationDefinition, 2, nil),
                .init(.enter, .fragmentDefinition, 3, nil),
                .init(.enter, .name, "name", .fragmentDefinition),
                .init(.leave, .name, "name", .fragmentDefinition),
                .init(.enter, .namedType, "typeCondition", .fragmentDefinition),
                .init(.enter, .name, "name", .namedType),
                .init(.leave, .name, "name", .namedType),
                .init(.leave, .namedType, "typeCondition", .fragmentDefinition),
                .init(.enter, .selectionSet, "selectionSet", .fragmentDefinition),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .argument, 1, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .variable, "value", .argument),
                .init(.enter, .name, "name", .variable),
                .init(.leave, .name, "name", .variable),
                .init(.leave, .variable, "value", .argument),
                .init(.leave, .argument, 1, nil),
                .init(.enter, .argument, 2, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .objectValue, "value", .argument),
                .init(.enter, .objectField, 0, nil),
                .init(.enter, .name, "name", .objectField),
                .init(.leave, .name, "name", .objectField),
                .init(.enter, .stringValue, "value", .objectField),
                .init(.leave, .stringValue, "value", .objectField),
                .init(.leave, .objectField, 0, nil),
                .init(.leave, .objectValue, "value", .argument),
                .init(.leave, .argument, 2, nil),
                .init(.leave, .field, 0, nil),
                .init(.leave, .selectionSet, "selectionSet", .fragmentDefinition),
                .init(.leave, .fragmentDefinition, 3, nil),
                .init(.enter, .operationDefinition, 4, nil),
                .init(.enter, .selectionSet, "selectionSet", .operationDefinition),
                .init(.enter, .field, 0, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.enter, .argument, 0, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .booleanValue, "value", .argument),
                .init(.leave, .booleanValue, "value", .argument),
                .init(.leave, .argument, 0, nil),
                .init(.enter, .argument, 1, nil),
                .init(.enter, .name, "name", .argument),
                .init(.leave, .name, "name", .argument),
                .init(.enter, .booleanValue, "value", .argument),
                .init(.leave, .booleanValue, "value", .argument),
                .init(.leave, .argument, 1, nil),
                .init(.leave, .field, 0, nil),
                .init(.enter, .field, 1, nil),
                .init(.enter, .name, "name", .field),
                .init(.leave, .name, "name", .field),
                .init(.leave, .field, 1, nil),
                .init(.leave, .selectionSet, "selectionSet", .operationDefinition),
                .init(.leave, .operationDefinition, 4, nil),
                .init(.leave, .document, nil, nil),
            ]
        )
    }
}

enum VisitDirection: Equatable {
    case enter
    case leave
}

struct VisitedPath {
    let direction: VisitDirection
    let path: [IndexPathElement]

    init(_ direction: VisitDirection, _ path: [IndexPathElement]) {
        self.direction = direction
        self.path = path
    }
}

extension VisitedPath: Equatable {
    static func == (lhs: VisitedPath, rhs: VisitedPath) -> Bool {
        return lhs.direction == rhs.direction &&
            zip(lhs.path, rhs.path).allSatisfy { lhs, rhs in
                lhs.description == rhs.description
            }
    }
}

struct VisitedKindAndParent {
    let direction: VisitDirection
    let kind: Kind
    let key: IndexPathElement?
    let parentKind: Kind?

    init(
        _ direction: VisitDirection,
        _ kind: Kind,
        _ key: IndexPathElement?,
        _ parentKind: Kind?
    ) {
        self.direction = direction
        self.kind = kind
        self.key = key
        self.parentKind = parentKind
    }
}

extension VisitedKindAndParent: Equatable {
    static func == (lhs: VisitedKindAndParent, rhs: VisitedKindAndParent) -> Bool {
        return lhs.direction == rhs.direction &&
            lhs.kind == rhs.kind &&
            lhs.key?.description == rhs.key?.description &&
            lhs.parentKind == rhs.parentKind
    }
}

extension VisitedKindAndParent: CustomDebugStringConvertible {
    var debugDescription: String {
        "(\(direction), \(kind), \(key.debugDescription), \(parentKind.debugDescription))"
    }
}

func checkVisitorFnArgs(
    _ ast: Document,
    _ node: Node,
    _ key: IndexPathElement?,
    _ parent: NodeResult?,
    _ path: [IndexPathElement],
    _ ancestors: [NodeResult],
    isEdited: Bool = false
) {
    guard let key = key else {
        if !isEdited {
            guard let node = node as? Document else {
                XCTFail()
                return
            }
            XCTAssertEqual(node, ast)
        }
        XCTAssertNil(parent)
        XCTAssert(path.isEmpty)
        XCTAssert(ancestors.isEmpty)
        return
    }
    XCTAssertEqual(path.last?.indexPathValue, key.indexPathValue)
    XCTAssertEqual(ancestors.count, path.count - 1)

    if !isEdited {
        var currentNode = NodeResult.node(ast)
        for (index, ancestor) in ancestors.enumerated() {
            XCTAssert(nodeResultsEqual(ancestor, currentNode))
            guard let nextNode = currentNode.get(key: path[index]) else {
                XCTFail()
                return
            }
            currentNode = nextNode
        }
        guard let parent = parent else {
            XCTFail()
            return
        }
        XCTAssert(nodeResultsEqual(parent, currentNode))
        guard let parentNode = parent.get(key: key) else {
            XCTFail()
            return
        }
        XCTAssert(nodeResultsEqual(parentNode, .node(node)))
    }
}

func nodeResultsEqual(_ n1: NodeResult, _ n2: NodeResult) -> Bool {
    switch n1 {
    case let .node(n1):
        switch n2 {
        case let .node(n2):
            return n1.kind == n2.kind && n1.loc == n2.loc
        default:
            return false
        }
    case let .array(n1):
        switch n2 {
        case let .array(n2):
            return zip(n1, n2).allSatisfy { n1, n2 in
                nodesEqual(n1, n2)
            }
        default:
            return false
        }
    }
}

func nodesEqual(_ n1: Node, _ n2: Node) -> Bool {
    return n1.kind == n2.kind && n1.loc == n2.loc
}

func getValue(node: Node) -> String? {
    switch node {
    case let node as IntValue:
        return node.value
    case let node as FloatValue:
        return node.value
    case let node as StringValue:
        return node.value
    case let node as BooleanValue:
        return node.value.description
    case let node as EnumValue:
        return node.value
    case let node as Name:
        return node.value
    default:
        return nil
    }
}
