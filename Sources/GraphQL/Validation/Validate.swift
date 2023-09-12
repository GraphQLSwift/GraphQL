/// Implements the "Validation" section of the spec.
///
/// Validation runs synchronously, returning an array of encountered errors, or
/// an empty array if no errors were encountered and the document is valid.
///
/// - Parameters:
///   - instrumentation: The instrumentation implementation to call during the parsing, validating,
/// execution, and field resolution stages.
///   - schema:          The GraphQL type system to use when validating and executing a query.
///   - ast:             A GraphQL document representing the requested operation.
/// - Returns: zero or more errors
public func validate(
    instrumentation: Instrumentation = NoOpInstrumentation,
    schema: GraphQLSchema,
    ast: Document
) -> [GraphQLError] {
    return validate(instrumentation: instrumentation, schema: schema, ast: ast, rules: [])
}

/**
 * Implements the "Validation" section of the spec.
 *
 * Validation runs synchronously, returning an array of encountered errors, or
 * an empty array if no errors were encountered and the document is valid.
 *
 * A list of specific validation rules may be provided. If not provided, the
 * default list of rules defined by the GraphQL specification will be used.
 *
 * Each validation rules is a function which returns a visitor
 * (see the language/visitor API). Visitor methods are expected to return
 * GraphQLErrors, or Arrays of GraphQLErrors when invalid.
 */
public func validate(
    instrumentation: Instrumentation = NoOpInstrumentation,
    schema: GraphQLSchema,
    ast: Document,
    rules: [(ValidationContext) -> Visitor]
) -> [GraphQLError] {
    let started = instrumentation.now
    let typeInfo = TypeInfo(schema: schema)
    let rules = rules.isEmpty ? specifiedRules : rules
    let errors = visit(usingRules: rules, schema: schema, typeInfo: typeInfo, documentAST: ast)
    instrumentation.queryValidation(
        processId: processId(),
        threadId: threadId(),
        started: started,
        finished: instrumentation.now,
        schema: schema,
        document: ast,
        errors: errors
    )
    return errors
}

/**
 * This uses a specialized visitor which runs multiple visitors in parallel,
 * while maintaining the visitor skip and break API.
 *
 * @internal
 */
func visit(
    usingRules rules: [(ValidationContext) -> Visitor],
    schema: GraphQLSchema,
    typeInfo: TypeInfo,
    documentAST: Document
) -> [GraphQLError] {
    let context = ValidationContext(schema: schema, ast: documentAST, typeInfo: typeInfo)
    let visitors = rules.map { rule in rule(context) }
    // Visit the whole document with each instance of all provided rules.
    visit(
        root: documentAST,
        visitor: visitWithTypeInfo(typeInfo: typeInfo, visitor: visitInParallel(visitors: visitors))
    )
    return context.errors
}

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

public typealias VariableUsage = (node: Variable, type: GraphQLInputType?)

/**
 * An instance of this class is passed as the "this" context to all validators,
 * allowing access to commonly useful contextual information from within a
 * validation rule.
 */
public final class ValidationContext {
    public let schema: GraphQLSchema
    let ast: Document
    let typeInfo: TypeInfo
    var errors: [GraphQLError]
    var fragments: [String: FragmentDefinition]
    var fragmentSpreads: [SelectionSet: [FragmentSpread]]
    var recursivelyReferencedFragments: [OperationDefinition: [FragmentDefinition]]
    var variableUsages: [HasSelectionSet: [VariableUsage]]
    var recursiveVariableUsages: [OperationDefinition: [VariableUsage]]

    init(schema: GraphQLSchema, ast: Document, typeInfo: TypeInfo) {
        self.schema = schema
        self.ast = ast
        self.typeInfo = typeInfo
        errors = []
        fragments = [:]
        fragmentSpreads = [:]
        recursivelyReferencedFragments = [:]
        variableUsages = [:]
        recursiveVariableUsages = [:]
    }

    public func report(error: GraphQLError) {
        errors.append(error)
    }

    public func getFragment(name: String) -> FragmentDefinition? {
        var fragments = self.fragments

        if fragments.isEmpty {
            fragments = ast.definitions.reduce([:]) { frags, statement in
                var frags = frags

                if let statement = statement as? FragmentDefinition {
                    frags[statement.name.value] = statement
                }

                return frags
            }

            self.fragments = fragments
        }

        return fragments[name]
    }

    public func getFragmentSpreads(node: SelectionSet) -> [FragmentSpread] {
        if let spreads = fragmentSpreads[node] {
            return spreads
        }

        var spreads = [FragmentSpread]()
        var setsToVisit: [SelectionSet] = [node]

        while let set = setsToVisit.popLast() {
            for selection in set.selections {
                if let selection = selection as? FragmentSpread {
                    spreads.append(selection)
                }

                if let selection = selection as? InlineFragment {
                    setsToVisit.append(selection.selectionSet)
                }

                if let selection = selection as? Field, let selectionSet = selection.selectionSet {
                    setsToVisit.append(selectionSet)
                }
            }
        }

        fragmentSpreads[node] = spreads
        return spreads
    }

    public func getRecursivelyReferencedFragments(operation: OperationDefinition)
        -> [FragmentDefinition]
    {
        if let fragments = recursivelyReferencedFragments[operation] {
            return fragments
        }

        var fragments = [FragmentDefinition]()
        var collectedNames: [String: Bool] = [:]
        var nodesToVisit: [SelectionSet] = [operation.selectionSet]

        while let node = nodesToVisit.popLast() {
            let spreads = getFragmentSpreads(node: node)

            for spread in spreads {
                let fragName = spread.name.value
                if collectedNames[fragName] != true {
                    collectedNames[fragName] = true
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
                            type: typeInfo.inputType
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

    public var fieldDef: GraphQLFieldDefinition? {
        return typeInfo.fieldDef
    }

    public var directive: GraphQLDirective? {
        return typeInfo.directive
    }

    public var argument: GraphQLArgumentDefinition? {
        return typeInfo.argument
    }
}
