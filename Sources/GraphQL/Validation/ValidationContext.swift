

public enum HasSelectionSet {
    case operation(OperationDefinition)
    case fragment(FragmentDefinition)

    public var node: Node {
        switch self {
        case let .operation(operation):
            return operation
        case let .fragment(fragment):
            return fragment
        }
    }
}

extension HasSelectionSet: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .operation(operation):
            return hasher.combine(operation.hashValue)
        case let .fragment(fragment):
            return hasher.combine(fragment.hashValue)
        }
    }

    public static func == (lhs: HasSelectionSet, rhs: HasSelectionSet) -> Bool {
        switch (lhs, rhs) {
        case let (.operation(l), .operation(r)):
            return l == r
        case let (.fragment(l), .fragment(r)):
            return l == r
        default:
            return false
        }
    }
}

public typealias VariableUsage = (node: Variable, type: GraphQLInputType?, defaultValue: Map?)

/**
 * An instance of this class is passed as the "this" context to all validators,
 * allowing access to commonly useful contextual information from within a
 * validation rule.
 */
public class ASTValidationContext {
    let ast: Document
    var onError: (GraphQLError) -> Void
    var fragments: [String: FragmentDefinition]?
    var fragmentSpreads: [SelectionSet: [FragmentSpread]]
    var recursivelyReferencedFragments: [OperationDefinition: [FragmentDefinition]]

    init(ast: Document, onError: @escaping (GraphQLError) -> Void) {
        self.ast = ast
        fragments = nil
        fragmentSpreads = [:]
        recursivelyReferencedFragments = [:]
        self.onError = onError
    }

    // get [Symbol.toStringTag]() {
    //   return 'ASTValidationContext';
    // }

    public func report(error: GraphQLError) {
        onError(error)
    }

    func getDocument() -> Document {
        return ast
    }

    public func getFragment(name: String) -> FragmentDefinition? {
        if let fragments = fragments {
            return fragments[name]
        } else {
            var fragments: [String: FragmentDefinition] = [:]
            for defNode in getDocument().definitions {
                if let defNode = defNode as? FragmentDefinition {
                    fragments[defNode.name.value] = defNode
                }
            }
            self.fragments = fragments
            return fragments[name]
        }
    }

    public func getFragmentSpreads(node: SelectionSet) -> [FragmentSpread] {
        // Uncommenting this creates unpredictably wrong fragment path matching.
        // Failures can be seen in NoFragmentCyclesRuleTests.testNoSpreadingItselfDeeplyTwoPaths
//        if let spreads = fragmentSpreads[node] {
//            return spreads
//        }

        var spreads = [FragmentSpread]()
        var setsToVisit: [SelectionSet] = [node]
        while let set = setsToVisit.popLast() {
            for selection in set.selections {
                if let spread = selection as? FragmentSpread {
                    spreads.append(spread)
                } else if let fragment = selection as? InlineFragment {
                    setsToVisit.append(fragment.selectionSet)
                } else if
                    let field = selection as? Field,
                    let selectionSet = field.selectionSet
                {
                    setsToVisit.append(selectionSet)
                }
            }
        }
//        fragmentSpreads[node] = spreads
        return spreads
    }

    public func getRecursivelyReferencedFragments(operation: OperationDefinition)
    -> [FragmentDefinition] {
        if let fragments = recursivelyReferencedFragments[operation] {
            return fragments
        }
        var fragments = [FragmentDefinition]()
        var collectedNames = Set<String>()
        var nodesToVisit = [operation.selectionSet]
        while let node = nodesToVisit.popLast() {
            for spread in getFragmentSpreads(node: node) {
                let fragName = spread.name.value
                if !collectedNames.contains(fragName) {
                    collectedNames.insert(fragName)
                    if let fragment = getFragment(name: fragName) {
                        fragments.append(fragment)
                        nodesToVisit.append(fragment.selectionSet)
                    }
                }
            }
        }
        recursivelyReferencedFragments[operation] = fragments
        return fragments
    }
}

typealias ValidationRule = (ValidationContext) -> Visitor

public class SDLValidationContext: ASTValidationContext {
    public let schema: GraphQLSchema?

    init(
        ast: Document,
        schema: GraphQLSchema?,
        onError: @escaping (GraphQLError) -> Void
    ) {
        self.schema = schema
        super.init(ast: ast, onError: onError)
    }

    // get [Symbol.toStringTag]() {
    //   return "SDLValidationContext";
    // }

    func getSchema() -> GraphQLSchema? {
        return schema
    }
}

public typealias SDLValidationRule = (SDLValidationContext) -> Visitor

/**
 * An instance of this class is passed as the "this" context to all validators,
 * allowing access to commonly useful contextual information from within a
 * validation rule.
 */
public final class ValidationContext: ASTValidationContext {
    public let schema: GraphQLSchema
    let typeInfo: TypeInfo
    var errors: [GraphQLError]
    var variableUsages: [HasSelectionSet: [VariableUsage]]
    var recursiveVariableUsages: [OperationDefinition: [VariableUsage]]

    init(schema: GraphQLSchema, ast: Document, typeInfo: TypeInfo) {
        self.schema = schema
        self.typeInfo = typeInfo
        errors = []
        variableUsages = [:]
        recursiveVariableUsages = [:]

        super.init(ast: ast) { _ in }
        onError = { error in
            self.errors.append(error)
        }
    }

    func getSchema() -> GraphQLSchema? {
        return schema
    }

    public func getVariableUsages(node: HasSelectionSet) -> [VariableUsage] {
        if let usages = variableUsages[node] {
            return usages
        }

        var usages = [VariableUsage]()
        let typeInfo = TypeInfo(schema: schema)

        visit(
            root: node.node,
            visitor: visitWithTypeInfo(
                typeInfo: typeInfo,
                visitor: Visitor(enter: { node, _, _, _, _ in
                    if node is VariableDefinition {
                        return .skip
                    }

                    if let variable = node as? Variable {
                        usages.append(VariableUsage(
                            node: variable,
                            type: typeInfo.inputType,
                            defaultValue: typeInfo.defaultValue
                        ))
                    }

                    return .continue
                })
            )
        )

        variableUsages[node] = usages
        return usages
    }

    public func getRecursiveVariableUsages(operation: OperationDefinition) -> [VariableUsage] {
        if let usages = recursiveVariableUsages[operation] {
            return usages
        }

        var usages = getVariableUsages(node: .operation(operation))
        let fragments = getRecursivelyReferencedFragments(operation: operation)

        for fragment in fragments {
            let newUsages = getVariableUsages(node: .fragment(fragment))
            usages.append(contentsOf: newUsages)
        }

        recursiveVariableUsages[operation] = usages
        return usages
    }

    public var type: GraphQLOutputType? {
        return typeInfo.type
    }

    public var parentType: GraphQLCompositeType? {
        return typeInfo.parentType
    }

    public var inputType: GraphQLInputType? {
        return typeInfo.inputType
    }

    public var parentInputType: GraphQLInputType? {
        return typeInfo.parentInputType
    }

    public var fieldDef: GraphQLFieldDefinition? {
        return typeInfo.fieldDef
    }

    public var directive: GraphQLDirective? {
        return typeInfo.directive
    }

    public var argument: GraphQLArgumentDefinition? {
        return typeInfo.argument
    }

    public var getEnumValue: GraphQLEnumValueDefinition? {
        return typeInfo.enumValue
    }
}

protocol SDLorNormalValidationContext {
    func getSchema() -> GraphQLSchema?
    var ast: Document { get }
    func report(error: GraphQLError)
}

extension ValidationContext: SDLorNormalValidationContext {}
extension SDLValidationContext: SDLorNormalValidationContext {}

let emptySchema = try! GraphQLSchema()
