@testable import GraphQL
import XCTest

class VisitorTests: XCTestCase {
    func testHandlesEmptyVisitor() throws {
        let ast = try parse(source: "{ a }", noLocation: true)
        XCTAssertNoThrow(visit(root: ast, visitor: .init()))
    }

    func testValidatesPathArgument() throws {
        struct VisitedElement: Equatable {
            let direction: VisitDirection
            let path: [any IndexPathElement]

            init(_ direction: VisitDirection, _ path: [any IndexPathElement]) {
                self.direction = direction
                self.path = path
            }

            static func == (lhs: VisitedElement, rhs: VisitedElement) -> Bool {
                return lhs.direction == rhs.direction &&
                    zip(lhs.path, rhs.path).allSatisfy { lhs, rhs in
                        lhs.description == rhs.description
                    }
            }
        }

        var visited = [VisitedElement]()
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
        struct VisitedElement: Equatable, CustomDebugStringConvertible {
            var debugDescription: String {
                "(\(direction), \(kind), \(key.debugDescription), \(parentKind.debugDescription))"
            }

            let direction: VisitDirection
            let kind: Kind
            let key: (any IndexPathElement)?
            let parentKind: Kind?

            init(
                _ direction: VisitDirection,
                _ kind: Kind,
                _ key: (any IndexPathElement)?,
                _ parentKind: Kind?
            ) {
                self.direction = direction
                self.kind = kind
                self.key = key
                self.parentKind = parentKind
            }

            static func == (lhs: VisitedElement, rhs: VisitedElement) -> Bool {
                return lhs.direction == rhs.direction &&
                    lhs.kind == rhs.kind &&
                    lhs.key?.description == rhs.key?.description &&
                    lhs.parentKind == rhs.parentKind
            }
        }
        var visited = [VisitedElement]()

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
