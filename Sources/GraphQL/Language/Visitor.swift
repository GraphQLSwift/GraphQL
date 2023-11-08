let QueryDocumentKeys: [Kind: [String]] = [
    .name: [],

    .document: ["definitions"],
    .operationDefinition: ["name", "variableDefinitions", "directives", "selectionSet"],
    .variableDefinition: ["variable", "type", "defaultValue"],
    .variable: ["name"],
    .selectionSet: ["selections"],
    .field: ["alias", "name", "arguments", "directives", "selectionSet"],
    .argument: ["name", "value"],

    .fragmentSpread: ["name", "directives"],
    .inlineFragment: ["typeCondition", "directives", "selectionSet"],
    .fragmentDefinition: ["name", "typeCondition", "directives", "selectionSet"],

    .intValue: [],
    .floatValue: [],
    .stringValue: [],
    .booleanValue: [],
    .enumValue: [],
    .listValue: ["values"],
    .objectValue: ["fields"],
    .objectField: ["name", "value"],

    .directive: ["name", "arguments"],

    .namedType: ["name"],
    .listType: ["type"],
    .nonNullType: ["type"],

    .schemaDefinition: ["directives", "operationTypes"],
    .operationTypeDefinition: ["type"],

    .scalarTypeDefinition: ["name", "directives"],
    .objectTypeDefinition: ["name", "interfaces", "directives", "fields"],
    .fieldDefinition: ["name", "arguments", "type", "directives"],
    .inputValueDefinition: ["name", "type", "defaultValue", "directives"],
    .interfaceTypeDefinition: ["name", "interfaces", "directives", "fields"],
    .unionTypeDefinition: ["name", "directives", "types"],
    .enumTypeDefinition: ["name", "directives", "values"],
    .enumValueDefinition: ["name", "directives"],
    .inputObjectTypeDefinition: ["name", "directives", "fields"],

    .typeExtensionDefinition: ["definition"],

    .directiveDefinition: ["name", "arguments", "locations"],
]

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
 *     let editedAST = visit(ast, Visitor(
 *         enter: { node, key, parent, path, ancestors in
 *             return
 *                 .continue: no action
 *                 .skip: skip visiting this node
 *                 .break: stop visiting altogether
 *                 .node(nil): delete this node
 *                 .node(newNode): replace this node with the returned value
 *         },
 *         leave: { node, key, parent, path, ancestors in
 *             return
 *                 .continue: no action
 *                 .skip: no action
 *                 .break: stop visiting altogether
 *                 .node(nil): delete this node
 *                 .node(newNode): replace this node with the returned value
 *         }
 *     ))
 */
@discardableResult
func visit(root: Node, visitor: Visitor, keyMap: [Kind: [String]] = [:]) -> Node {
    let visitorKeys = keyMap.isEmpty ? QueryDocumentKeys : keyMap

    var stack: Stack?
    var inArray = false
    var keys: [IndexPathElement] = ["root"]
    var index: Int = -1
    var edits: [(key: IndexPathElement, node: Node?)] = []
    var node: NodeResult? = .node(root)
    var key: IndexPathElement?
    var parent: NodeResult?
    var path: [IndexPathElement] = []
    var ancestors: [NodeResult] = []

    repeat {
        index += 1
        let isLeaving = index == keys.count
        let isEdited = isLeaving && !edits.isEmpty

        if isLeaving {
            key = ancestors.isEmpty ? nil : path.last
            node = parent
            parent = ancestors.popLast()

            if isEdited {
                if inArray {
                    var editOffset = 0
                    for (editKey, editValue) in edits {
                        let editKey = editKey.indexValue!
                        let arrayKey = editKey - editOffset

                        if case var .array(n) = node {
                            if let editValue = editValue {
                                n[arrayKey] = editValue
                                node = .array(n)
                            } else {
                                n.remove(at: arrayKey)
                                node = .array(n)
                                editOffset += 1
                            }
                        }
                    }
                } else {
                    let clone = node
                    node = clone
                    for (editKey, editValue) in edits {
                        if case .node(let node) = node {
                            node.set(value: editValue, key: editKey.keyValue!)
                        }
                    }
                }
            }

            index = stack!.index
            keys = stack!.keys
            edits = stack!.edits
            inArray = stack!.inArray
            stack = stack!.prev
        } else if let parent = parent {
            key = inArray ? index : keys[index]

            switch parent {
            case let .node(parent):
                node = parent.get(key: key!.keyValue!)
            case let .array(parent):
                node = .node(parent[key!.indexValue!])
            }

            if node == nil {
                continue
            }
            path.append(key!)
        }

        var result: VisitResult = .break // placeholder
        if case let .node(n) = node {
            if !isLeaving {
                result = visitor.enter(
                    node: n,
                    key: key,
                    parent: parent,
                    path: path,
                    ancestors: ancestors
                )
            } else {
                result = visitor.leave(
                    node: n,
                    key: key,
                    parent: parent,
                    path: path,
                    ancestors: ancestors
                )
            }

            if case .break = result {
                break
            }

            if case .skip = result {
                if !isLeaving {
                    _ = path.popLast()
                    continue
                }
            } else if case let .node(resultNode) = result {
                edits.append((key!, resultNode))
                if !isLeaving {
                    if let resultNode = resultNode {
                        node = .node(resultNode)
                    } else {
                        _ = path.popLast()
                        continue
                    }
                }
            }
        }

        if case .continue = result, isEdited, case let .node(node) = node! {
            edits.append((key!, node))
        }

        if isLeaving {
            _ = path.popLast()
        } else {
            stack = Stack(index: index, keys: keys, edits: edits, inArray: inArray, prev: stack)
            inArray = node!.isArray
            switch node! {
            case let .node(node):
                keys = visitorKeys[node.kind] ?? []
            case let .array(array):
                keys = array.map { _ in "root" }
            }
            index = -1
            edits = []
            if let parent = parent {
                ancestors.append(parent)
            }
            parent = node
        }
    } while
        stack != nil

    if !edits.isEmpty, let nextEditNode = edits[edits.count - 1].node {
        return nextEditNode
    }

    return root
}

final class Stack {
    let index: Int
    let keys: [IndexPathElement]
    let edits: [(key: IndexPathElement, node: Node?)]
    let inArray: Bool
    let prev: Stack?

    init(
        index: Int,
        keys: [IndexPathElement],
        edits: [(key: IndexPathElement, node: Node?)],
        inArray: Bool,
        prev: Stack?
    ) {
        self.index = index
        self.keys = keys
        self.edits = edits
        self.inArray = inArray
        self.prev = prev
    }
}

/**
 * Creates a new visitor instance which delegates to many visitors to run in
 * parallel. Each visitor will be visited for each node before moving on.
 *
 * If a prior visitor edits a node, no following visitors will see that node.
 */
func visitInParallel(visitors: [Visitor]) -> Visitor {
    var skipping = [VisitResult?](repeating: nil, count: visitors.count)

    return Visitor(
        enter: { node, key, parent, path, ancestors in
            for i in 0 ..< visitors.count {
                if skipping[i] == nil {
                    let result = visitors[i].enter(
                        node: node,
                        key: key,
                        parent: parent,
                        path: path,
                        ancestors: ancestors
                    )

                    if case .skip = result {
                        skipping[i] = .node(node)
                    } else if case .break = result {
                        skipping[i] = .break
                    } else if case .node = result {
                        return result
                    }
                }
            }

            return .continue
        },
        leave: { node, key, parent, path, ancestors in
            for i in 0 ..< visitors.count {
                if skipping[i] == nil {
                    let result = visitors[i].leave(
                        node: node,
                        key: key,
                        parent: parent,
                        path: path,
                        ancestors: ancestors
                    )

                    if case .break = result {
                        skipping[i] = .break
                    } else if case .node = result {
                        return result
                    }
                } // else if case let .node(skippedNode) = skipping[i], skippedNode == node {
//                    skipping[i] = nil
//                }
            }

            return .continue
        }
    )
}

public enum VisitResult {
    case `continue`
    case skip
    case `break`
    case node(Node?)

    public var isContinue: Bool {
        if case .continue = self {
            return true
        }
        return false
    }
}

/// A visitor is provided to visit, it contains the collection of
/// relevant functions to be called during the visitor's traversal.
public struct Visitor {
    /// A visitor is comprised of visit functions, which are called on each node during the
    /// visitor's traversal.
    public typealias Visit = (
        Node,
        IndexPathElement?,
        NodeResult?,
        [IndexPathElement],
        [NodeResult]
    ) -> VisitResult
    private let enter: Visit
    private let leave: Visit

    public init(enter: @escaping Visit = ignore, leave: @escaping Visit = ignore) {
        self.enter = enter
        self.leave = leave
    }

    public func enter(
        node: Node,
        key: IndexPathElement?,
        parent: NodeResult?,
        path: [IndexPathElement],
        ancestors: [NodeResult]
    ) -> VisitResult {
        return enter(node, key, parent, path, ancestors)
    }

    public func leave(
        node: Node,
        key: IndexPathElement?,
        parent: NodeResult?,
        path: [IndexPathElement],
        ancestors: [NodeResult]
    ) -> VisitResult {
        return leave(node, key, parent, path, ancestors)
    }
}

public func ignore(
    node _: Node,
    key _: IndexPathElement?,
    parent _: NodeResult?,
    path _: [IndexPathElement],
    ancestors _: [NodeResult]
) -> VisitResult {
    return .continue
}

/**
 * Creates a new visitor instance which maintains a provided TypeInfo instance
 * along with visiting visitor.
 */
func visitWithTypeInfo(typeInfo: TypeInfo, visitor: Visitor) -> Visitor {
    return Visitor(
        enter: { node, key, parent, path, ancestors in
            typeInfo.enter(node: node)

            let result = visitor.enter(
                node: node,
                key: key,
                parent: parent,
                path: path,
                ancestors: ancestors
            )

            if !result.isContinue {
                typeInfo.leave(node: node)

                if case let .node(node) = result, let n = node {
                    typeInfo.enter(node: n)
                }
            }

            return result
        },
        leave: { node, key, parent, path, ancestors in
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
    )
}
