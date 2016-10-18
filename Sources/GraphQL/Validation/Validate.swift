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
func validate(schema: GraphQLSchema, ast: Document, rules: [(ValidationContext) -> Visitor] = []) throws -> [GraphQLError] {
    let typeInfo = TypeInfo(schema: schema)
    let rules = rules.isEmpty ? specifiedRules : rules
    return try visit(usingRules: rules, schema: schema, typeInfo: typeInfo, documentAST: ast)
}

/**
 * This uses a specialized visitor which runs multiple visitors in parallel,
 * while maintaining the visitor skip and break API.
 *
 * @internal
 */
func visit(usingRules rules: [(ValidationContext) -> Visitor], schema: GraphQLSchema, typeInfo: TypeInfo, documentAST: Document) throws -> [GraphQLError] {
    let context = ValidationContext(schema: schema, ast: documentAST, typeInfo: typeInfo)
    let visitors = rules.map({ rule in rule(context) })
  // Visit the whole document with each instance of all provided rules.
  try visit(root: documentAST, visitor: visitWithTypeInfo(typeInfo: typeInfo, visitor: visitInParallel(visitors: visitors)))
  return context.errors
}

public enum HasSelectionSet : Hashable {
    case operation(OperationDefinition)
    case fragment(FragmentDefinition)

    public var hashValue: Int {
        switch self {
        case .operation(let operation):
            return operation.hashValue
        case .fragment(let fragment):
            return fragment.hashValue
        }
    }
}

public func == (lhs: HasSelectionSet, rhs: HasSelectionSet) -> Bool {
    switch (lhs, rhs) {
    case (.operation(let l), .operation(let r)):
        return l == r
    case (.fragment(let l), .fragment(let r)):
        return l == r
    default:
        return false
    }
}

public typealias VariableUsage = (node: Variable, type: GraphQLInputType?)

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
    var fragmentSpreads: [SelectionSet: [FragmentSpread]]
    var recursivelyReferencedFragments: [OperationDefinition: [FragmentDefinition]]
    var variableUsages: [HasSelectionSet: [VariableUsage]]
    var recursiveVariableUsages: [OperationDefinition: [VariableUsage]]

    init(schema: GraphQLSchema, ast: Document, typeInfo: TypeInfo) {
        self.schema = schema
        self.ast = ast
        self.typeInfo = typeInfo
        self.errors = []
        self.fragments = [:]
        self.fragmentSpreads = [:]
        self.recursivelyReferencedFragments = [:]
        self.variableUsages = [:]
        self.recursiveVariableUsages = [:]
    }

    func report(error: GraphQLError) {
        errors.append(error)
    }

    func getFragment(name: String) -> FragmentDefinition? {
        var fragments = self.fragments

        if fragments.isEmpty {
            var frags: [String: FragmentDefinition] = [:]

//            fragments = document.definitions.
//            fragments = document.definitions.reduce((frags, statement) => {
//                if (statement.kind === Kind.FRAGMENT_DEFINITION) {
//                    frags[statement.name.value] = statement;
//                }
//                return frags;
//                }, {});
            self.fragments = fragments
        }

        return fragments[name]
    }

    func getFragmentSpreads(node: SelectionSet) -> [FragmentSpread] {
        var spreads = fragmentSpreads[node]

        if spreads == nil {
            spreads = []
            var setsToVisit: [SelectionSet] = [node]

            while let set = setsToVisit.popLast() {
//                for selection in set.selections {
//                    if selection.kind == .fragmentSpread {
//                        spreads.append(selection)
//                    } else if selection.selectionSet != nil {
//                        setsToVisit.append(selection.selectionSet)
//                    }
//                }
            }

            fragmentSpreads[node] = spreads
        }

        return spreads!
    }

    func getRecursivelyReferencedFragments(operation: OperationDefinition) -> [FragmentDefinition] {
        var fragments = recursivelyReferencedFragments[operation]

        if fragments == nil {
            fragments = []
            var collectedNames: [String: Bool] = [:]
            var nodesToVisit: [SelectionSet] = [operation.selectionSet]

            while let node = nodesToVisit.popLast() {
                let spreads = getFragmentSpreads(node: node)

                for spread in spreads {
                    let fragName = spread.name.value
                    if collectedNames[fragName] != true {
                        collectedNames[fragName] = true
                        if let fragment = getFragment(name: fragName) {
                            fragments!.append(fragment)
                            nodesToVisit.append(fragment.selectionSet)
                        }
                    }
                }
            }
            
            recursivelyReferencedFragments[operation] = fragments
        }
        
        return fragments!
    }

    func getVariableUsages(node: HasSelectionSet) -> [VariableUsage] {
        var usages = variableUsages[node]

        if usages == nil {
            var newUsages: [VariableUsage] = []
            let typeInfo = TypeInfo(schema: schema)
//            visit(node, visitWithTypeInfo(typeInfo, {
//                VariableDefinition: () => false,
//                Variable(variable) {
//                    newUsages.push({ node: variable, type: typeInfo.getInputType() });
//                }
//            }
            usages = newUsages
            variableUsages[node] = usages
        }

        return usages!
    }

    func getRecursiveVariableUsages(operation: OperationDefinition) -> [VariableUsage] {
        var usages = recursiveVariableUsages[operation]

        if usages == nil {
            usages = getVariableUsages(node: .operation(operation))
            let fragments = getRecursivelyReferencedFragments(operation: operation)

            for fragment in fragments {
                let newUsages = getVariableUsages(node: .fragment(fragment))
                usages!.append(contentsOf: newUsages)
            }

            recursiveVariableUsages[operation] = usages
        }
        
        return usages!
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

    var argument: GraphQLArgument? {
        return typeInfo.argument
    }
}
