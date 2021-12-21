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
 *
 * - Parameters:
 *   - instrumentation: The instrumentation implementation to call during the parsing, validating, execution, and field resolution stages.
 *   - schema:          The GraphQL type system to use when validating and executing a query.
 *   - ast:             A GraphQL document representing the requested operation.
 */

public func validate(
    instrumentation: Instrumentation = NoOpInstrumentation,
    schema: GraphQLSchema,
    ast: Document
) -> [GraphQLError] {
    validate(instrumentation: instrumentation, schema: schema, ast: ast, rules: specifiedRules)
}

/**
 * An internal version of `validate` that lets you specify custom validation rules.
 *
 * - Parameters:
 *   - rules:           A list of specific validation rules. If not provided, the default list of rules defined by the GraphQL specification will be used.
 */
func validate(
    instrumentation: Instrumentation = NoOpInstrumentation,
    schema: GraphQLSchema,
    ast: Document,
    rules: [ValidationRule.Type]
) -> [GraphQLError] {
    let started = instrumentation.now
    let typeInfo = TypeInfo(schema: schema)
    let errors = visit(usingRules: rules, schema: schema, typeInfo: typeInfo, documentAST: ast)
    instrumentation.queryValidation(processId: processId(), threadId: threadId(), started: started, finished: instrumentation.now, schema: schema, document: ast, errors: errors)
    return errors
}

protocol ValidationRule: Visitor {
    init(context: ValidationContext)
}

/**
 * This uses a specialized visitor which runs multiple visitors in parallel,
 * while maintaining the visitor skip and break API.
 *
 * @internal
 */
func visit(
    usingRules rules: [ValidationRule.Type],
    schema: GraphQLSchema,
    typeInfo: TypeInfo,
    documentAST: Document
) -> [GraphQLError] {
    let context = ValidationContext(schema: schema, ast: documentAST, typeInfo: typeInfo)
    let visitors = rules.map({ rule in rule.init(context: context) })
    // Visit the whole document with each instance of all provided rules.
    visit(root: documentAST, visitor: VisitorWithTypeInfo(
        visitor: ParallelVisitor(visitors: visitors),
        typeInfo: typeInfo
    ))
    return context.errors
}

protocol HasSelectionSet: Node {
    var selectionSet: SelectionSet { get }
}

extension OperationDefinition: HasSelectionSet { }
extension FragmentDefinition: HasSelectionSet { }


typealias VariableUsage = (node: Variable, type: GraphQLInputType?)

/**
 * An instance of this class is passed as the "this" context to all validators,
 * allowing access to commonly useful contextual information from within a
 * validation rule.
 */
final class ValidationContext {
    let schema: GraphQLSchema
    let ast: Document
    let typeInfo: TypeInfo
    var errors: [GraphQLError]
    var fragments: [String: FragmentDefinition]
    // TODO: memoise all these caches
//    var fragmentSpreads: [SelectionSet: [FragmentSpread]]
//    var recursivelyReferencedFragments: [OperationDefinition: [FragmentDefinition]]
//    var variableUsages: [HasSelectionSet: [VariableUsage]]
//    var recursiveVariableUsages: [OperationDefinition: [VariableUsage]]

    init(schema: GraphQLSchema, ast: Document, typeInfo: TypeInfo) {
        self.schema = schema
        self.ast = ast
        self.typeInfo = typeInfo
        self.errors = []
        self.fragments = [:]
//        self.fragmentSpreads = [:]
//        self.recursivelyReferencedFragments = [:]
//        self.variableUsages = [:]
//        self.recursiveVariableUsages = [:]
    }

    func report(error: GraphQLError) {
        errors.append(error)
    }

    func getFragment(name: String) -> FragmentDefinition? {
        var fragments = self.fragments

        if fragments.isEmpty {
            fragments = ast.definitions.reduce([:]) { frags, statement in
                var frags = frags

                if case let .executableDefinition(.fragment(statement)) = statement {
                    frags[statement.name.value] = statement
                }

                return frags
            }

            self.fragments = fragments
        }

        return fragments[name]
    }

    func getFragmentSpreads(node: SelectionSet) -> [FragmentSpread] {
        var spreads: [FragmentSpread] = []
        var setsToVisit: [SelectionSet] = [node]

        while let set = setsToVisit.popLast() {
            for selection in set.selections {
                switch selection {
                case let .fragmentSpread(fragmentSpread):
                    spreads.append(fragmentSpread)
                case let .inlineFragment(inlineFragment):
                    setsToVisit.append(inlineFragment.selectionSet)
                case let .field(field):
                    if let selectionSet = field.selectionSet {
                        setsToVisit.append(selectionSet)
                    }
                }
            }
        }
        return spreads
    }

    func getRecursivelyReferencedFragments(operation: OperationDefinition) -> [FragmentDefinition] {
        var fragments: [FragmentDefinition] = []
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
        return fragments
    }
    
    class VariableUsageFinder: Visitor {
        var newUsages: [VariableUsage] = []
        let typeInfo: TypeInfo
        init(typeInfo: TypeInfo) { self.typeInfo = typeInfo }
        func enter(variableDefinition: VariableDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<VariableDefinition> {
            .skip
        }
        func enter(variable: Variable, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Variable> {
            newUsages.append(VariableUsage(node: variable, type: typeInfo.inputType))
            return .continue
        }
    }

    func getVariableUsages<T: HasSelectionSet>(node: T) -> [VariableUsage] {
        let typeInfo = TypeInfo(schema: schema)
        let visitor = VariableUsageFinder(typeInfo: typeInfo)
        visit(root: node, visitor: VisitorWithTypeInfo(visitor: visitor, typeInfo: typeInfo))
        return visitor.newUsages
    }

    func getRecursiveVariableUsages(operation: OperationDefinition) -> [VariableUsage] {
        var usages = getVariableUsages(node: operation)
        let fragments = getRecursivelyReferencedFragments(operation: operation)
        
        for fragment in fragments {
            let newUsages = getVariableUsages(node: fragment)
            usages.append(contentsOf: newUsages)
        }
        return usages
    }

    var type: GraphQLOutputType? {
        return typeInfo.type
    }

    var parentType: GraphQLCompositeType? {
        return typeInfo.parentType
    }

    var inputType: GraphQLInputType? {
        return typeInfo.inputType
    }

    var fieldDef: GraphQLFieldDefinition? {
        return typeInfo.fieldDef
    }

    var directive: GraphQLDirective? {
        return typeInfo.directive
    }

    var argument: GraphQLArgumentDefinition? {
        return typeInfo.argument
    }
}
