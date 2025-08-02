import Dispatch
import OrderedCollections

/**
 * Terminology
 *
 * "Definitions" are the generic name for top-level statements in the document.
 * Examples of this include:
 * 1) Operations (such as a query)
 * 2) Fragments
 *
 * "Operations" are a generic name for requests in the document.
 * Examples of this include:
 * 1) query,
 * 2) mutation
 *
 * "Selections" are the definitions that can appear legally and at
 * single level of the query. These include:
 * 1) field references e.g "a"
 * 2) fragment "spreads" e.g. "...c"
 * 3) inline fragment "spreads" e.g. "...on Type { a }"
 */

/**
 * Data that must be available at all points during query execution.
 *
 * Namely, schema of the type system that is currently executing,
 * and the fragments defined in the query document
 */
public final class ExecutionContext: @unchecked Sendable {
    let queryStrategy: QueryFieldExecutionStrategy
    let mutationStrategy: MutationFieldExecutionStrategy
    let subscriptionStrategy: SubscriptionFieldExecutionStrategy
    public let schema: GraphQLSchema
    public let fragments: [String: FragmentDefinition]
    public let rootValue: any Sendable
    public let context: any Sendable
    public let operation: OperationDefinition
    public let variableValues: [String: Map]

    private var errorsSemaphore = DispatchSemaphore(value: 1)
    private var _errors: [GraphQLError]

    public var errors: [GraphQLError] {
        errorsSemaphore.wait()
        defer {
            errorsSemaphore.signal()
        }
        return _errors
    }

    init(
        queryStrategy: QueryFieldExecutionStrategy,
        mutationStrategy: MutationFieldExecutionStrategy,
        subscriptionStrategy: SubscriptionFieldExecutionStrategy,
        schema: GraphQLSchema,
        fragments: [String: FragmentDefinition],
        rootValue: any Sendable,
        context: any Sendable,
        operation: OperationDefinition,
        variableValues: [String: Map],
        errors: [GraphQLError]
    ) {
        self.queryStrategy = queryStrategy
        self.mutationStrategy = mutationStrategy
        self.subscriptionStrategy = subscriptionStrategy
        self.schema = schema
        self.fragments = fragments
        self.rootValue = rootValue
        self.context = context
        self.operation = operation
        self.variableValues = variableValues
        _errors = errors
    }

    public func append(error: GraphQLError) {
        errorsSemaphore.wait()
        defer {
            errorsSemaphore.signal()
        }
        _errors.append(error)
    }
}

public protocol FieldExecutionStrategy: Sendable {
    func executeFields(
        exeContext: ExecutionContext,
        parentType: GraphQLObjectType,
        sourceValue: any Sendable,
        path: IndexPath,
        fields: OrderedDictionary<String, [Field]>
    ) async throws -> OrderedDictionary<String, any Sendable>
}

public protocol MutationFieldExecutionStrategy: FieldExecutionStrategy {}
public protocol QueryFieldExecutionStrategy: FieldExecutionStrategy {}
public protocol SubscriptionFieldExecutionStrategy: FieldExecutionStrategy {}

/**
 * Serial field execution strategy that's suitable for the "Evaluating selection sets" section of the spec for "write" mode.
 */
public struct SerialFieldExecutionStrategy: QueryFieldExecutionStrategy,
    MutationFieldExecutionStrategy, SubscriptionFieldExecutionStrategy
{
    public init() {}

    public func executeFields(
        exeContext: ExecutionContext,
        parentType: GraphQLObjectType,
        sourceValue: any Sendable,
        path: IndexPath,
        fields: OrderedDictionary<String, [Field]>
    ) async throws -> OrderedDictionary<String, any Sendable> {
        var results = OrderedDictionary<String, any Sendable>()
        for field in fields {
            let fieldASTs = field.value
            let fieldPath = path.appending(field.key)
            results[field.key] = try await resolveField(
                exeContext: exeContext,
                parentType: parentType,
                source: sourceValue,
                fieldASTs: fieldASTs,
                path: fieldPath
            ) ?? Map.null
        }
        return results
    }
}

/**
 * Serial field execution strategy that's suitable for the "Evaluating selection sets" section of the spec for "read" mode.
 *
 * Each field is resolved as an individual task on a concurrent dispatch queue.
 */
public struct ConcurrentFieldExecutionStrategy: QueryFieldExecutionStrategy,
    SubscriptionFieldExecutionStrategy
{
    public func executeFields(
        exeContext: ExecutionContext,
        parentType: GraphQLObjectType,
        sourceValue: any Sendable,
        path: IndexPath,
        fields: OrderedDictionary<String, [Field]>
    ) async throws -> OrderedDictionary<String, any Sendable> {
        return try await withThrowingTaskGroup(of: (String, (any Sendable)?).self) { group in
            // preserve field order by assigning to null and filtering later
            var results: OrderedDictionary<String, (any Sendable)?> = fields
                .mapValues { _ -> Any? in nil }
            for field in fields {
                group.addTask {
                    let fieldASTs = field.value
                    let fieldPath = path.appending(field.key)
                    let result = try await resolveField(
                        exeContext: exeContext,
                        parentType: parentType,
                        source: sourceValue,
                        fieldASTs: fieldASTs,
                        path: fieldPath
                    ) ?? Map.null
                    return (field.key, result)
                }
            }
            for try await result in group {
                results[result.0] = result.1
            }
            return results.compactMapValues { $0 }
        }
    }
}

/**
 * Implements the "Evaluating requests" section of the GraphQL specification.
 *
 * If the arguments to this func do not result in a legal execution context,
 * a GraphQLError will be thrown immediately explaining the invalid input.
 */
func execute(
    queryStrategy: QueryFieldExecutionStrategy,
    mutationStrategy: MutationFieldExecutionStrategy,
    subscriptionStrategy: SubscriptionFieldExecutionStrategy,
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: any Sendable,
    context: any Sendable,
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) async throws -> GraphQLResult {
    let buildContext: ExecutionContext

    do {
        // If a valid context cannot be created due to incorrect arguments,
        // this will throw an error.
        buildContext = try buildExecutionContext(
            queryStrategy: queryStrategy,
            mutationStrategy: mutationStrategy,
            subscriptionStrategy: subscriptionStrategy,
            schema: schema,
            documentAST: documentAST,
            rootValue: rootValue,
            context: context,
            rawVariableValues: variableValues,
            operationName: operationName
        )
    } catch let error as GraphQLError {
        return GraphQLResult(errors: [error])
    } catch {
        return GraphQLResult(errors: [GraphQLError(error)])
    }

    do {
//        var executeErrors: [GraphQLError] = []
        let data = try await executeOperation(
            exeContext: buildContext,
            operation: buildContext.operation,
            rootValue: rootValue
        )
        var dataMap: Map = [:]

        for (key, value) in data {
            dataMap[key] = try map(from: value)
        }

        var result: GraphQLResult = .init(data: dataMap)

        if !buildContext.errors.isEmpty {
            result.errors = buildContext.errors
        }

//            executeErrors = buildContext.errors
        return result
    } catch let error as GraphQLError {
        return GraphQLResult(errors: [error])
    } catch {
        return GraphQLResult(errors: [GraphQLError(error)])
    }
}

/**
 * Constructs a ExecutionContext object from the arguments passed to
 * execute, which we will pass throughout the other execution methods.
 *
 * Throws a GraphQLError if a valid execution context cannot be created.
 */
func buildExecutionContext(
    queryStrategy: QueryFieldExecutionStrategy,
    mutationStrategy: MutationFieldExecutionStrategy,
    subscriptionStrategy: SubscriptionFieldExecutionStrategy,
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: any Sendable,
    context: any Sendable,
    rawVariableValues: [String: Map],
    operationName: String?
) throws -> ExecutionContext {
    let errors: [GraphQLError] = []
    var possibleOperation: OperationDefinition?
    var fragments: [String: FragmentDefinition] = [:]

    for definition in documentAST.definitions {
        switch definition {
        case let definition as OperationDefinition:
            guard !(operationName == nil && possibleOperation != nil) else {
                throw GraphQLError(
                    message: "Must provide operation name if query contains multiple operations."
                )
            }

            if operationName == nil || definition.name?.value == operationName {
                possibleOperation = definition
            }

        case let definition as FragmentDefinition:
            fragments[definition.name.value] = definition

        default:
            throw GraphQLError(
                message: "GraphQL cannot execute a request containing a \(definition.kind).",
                nodes: [definition]
            )
        }
    }

    guard let operation = possibleOperation else {
        if let operationName = operationName {
            throw GraphQLError(message: "Unknown operation named \"\(operationName)\".")
        } else {
            throw GraphQLError(message: "Must provide an operation.")
        }
    }

    let variableValues = try getVariableValues(
        schema: schema,
        definitionASTs: operation.variableDefinitions,
        inputs: rawVariableValues
    )

    return ExecutionContext(
        queryStrategy: queryStrategy,
        mutationStrategy: mutationStrategy,
        subscriptionStrategy: subscriptionStrategy,
        schema: schema,
        fragments: fragments,
        rootValue: rootValue,
        context: context,
        operation: operation,
        variableValues: variableValues,
        errors: errors
    )
}

/**
 * Implements the "Evaluating operations" section of the spec.
 */
func executeOperation(
    exeContext: ExecutionContext,
    operation: OperationDefinition,
    rootValue: any Sendable
) async throws -> OrderedDictionary<String, any Sendable> {
    let type = try getOperationRootType(schema: exeContext.schema, operation: operation)
    var inputFields: OrderedDictionary<String, [Field]> = [:]
    var visitedFragmentNames: [String: Bool] = [:]

    let fields = try collectFields(
        exeContext: exeContext,
        runtimeType: type,
        selectionSet: operation.selectionSet,
        fields: &inputFields,
        visitedFragmentNames: &visitedFragmentNames
    )

    let fieldExecutionStrategy: FieldExecutionStrategy

    switch operation.operation {
    case .query:
        fieldExecutionStrategy = exeContext.queryStrategy
    case .mutation:
        fieldExecutionStrategy = exeContext.mutationStrategy
    case .subscription:
        fieldExecutionStrategy = exeContext.subscriptionStrategy
    }

    return try await fieldExecutionStrategy.executeFields(
        exeContext: exeContext,
        parentType: type,
        sourceValue: rootValue,
        path: [],
        fields: fields
    )
}

/**
 * Extracts the root type of the operation from the schema.
 */
func getOperationRootType(
    schema: GraphQLSchema,
    operation: OperationDefinition
) throws -> GraphQLObjectType {
    switch operation.operation {
    case .query:
        guard let queryType = schema.queryType else {
            throw GraphQLError(
                message: "Schema is not configured for queries",
                nodes: [operation]
            )
        }

        return queryType
    case .mutation:
        guard let mutationType = schema.mutationType else {
            throw GraphQLError(
                message: "Schema is not configured for mutations",
                nodes: [operation]
            )
        }

        return mutationType
    case .subscription:
        guard let subscriptionType = schema.subscriptionType else {
            throw GraphQLError(
                message: "Schema is not configured for subscriptions",
                nodes: [operation]
            )
        }

        return subscriptionType
    }
}

/**
 * Given a selectionSet, adds all of the fields in that selection to
 * the passed in map of fields, and returns it at the end.
 *
 * CollectFields requires the "runtime type" of an object. For a field which
 * returns and Interface or Union type, the "runtime type" will be the actual
 * Object type returned by that field.
 */
@discardableResult
func collectFields(
    exeContext: ExecutionContext,
    runtimeType: GraphQLObjectType,
    selectionSet: SelectionSet,
    fields: inout OrderedDictionary<String, [Field]>,
    visitedFragmentNames: inout [String: Bool]
) throws -> OrderedDictionary<String, [Field]> {
    var visitedFragmentNames = visitedFragmentNames

    for selection in selectionSet.selections {
        switch selection {
        case let field as Field:
            let shouldInclude = try shouldIncludeNode(
                exeContext: exeContext,
                directives: field.directives
            )

            guard shouldInclude else {
                continue
            }

            let name = getFieldEntryKey(node: field)

            if fields[name] == nil {
                fields[name] = []
            }

            fields[name]?.append(field)
        case let inlineFragment as InlineFragment:
            let shouldInclude = try shouldIncludeNode(
                exeContext: exeContext,
                directives: inlineFragment.directives
            )

            let fragmentConditionMatches = try doesFragmentConditionMatch(
                exeContext: exeContext,
                fragment: inlineFragment,
                type: runtimeType
            )

            guard shouldInclude, fragmentConditionMatches else {
                continue
            }

            try collectFields(
                exeContext: exeContext,
                runtimeType: runtimeType,
                selectionSet: inlineFragment.selectionSet,
                fields: &fields,
                visitedFragmentNames: &visitedFragmentNames
            )
        case let fragmentSpread as FragmentSpread:
            let fragmentName = fragmentSpread.name.value

            let shouldInclude = try shouldIncludeNode(
                exeContext: exeContext,
                directives: fragmentSpread.directives
            )

            guard visitedFragmentNames[fragmentName] == nil, shouldInclude else {
                continue
            }

            visitedFragmentNames[fragmentName] = true

            guard let fragment = exeContext.fragments[fragmentName] else {
                continue
            }

            let fragmentConditionMatches = try doesFragmentConditionMatch(
                exeContext: exeContext,
                fragment: fragment,
                type: runtimeType
            )

            guard fragmentConditionMatches else {
                continue
            }

            try collectFields(
                exeContext: exeContext,
                runtimeType: runtimeType,
                selectionSet: fragment.selectionSet,
                fields: &fields,
                visitedFragmentNames: &visitedFragmentNames
            )
        default:
            break
        }
    }

    return fields
}

/**
 * Determines if a field should be included based on the @include and @skip
 * directives, where @skip has higher precidence than @include.
 */
func shouldIncludeNode(exeContext: ExecutionContext, directives: [Directive] = []) throws -> Bool {
    if let skipAST = directives.find({ $0.name.value == GraphQLSkipDirective.name }) {
        let skip = try getArgumentValues(
            argDefs: GraphQLSkipDirective.args,
            argASTs: skipAST.arguments,
            variables: exeContext.variableValues
        )

        if skip["if"] == .bool(true) {
            return false
        }
    }

    if let includeAST = directives.find({ $0.name.value == GraphQLIncludeDirective.name }) {
        let include = try getArgumentValues(
            argDefs: GraphQLIncludeDirective.args,
            argASTs: includeAST.arguments,
            variables: exeContext.variableValues
        )

        if include["if"] == .bool(false) {
            return false
        }
    }

    return true
}

/**
 * Determines if a fragment is applicable to the given type.
 */
func doesFragmentConditionMatch(
    exeContext: ExecutionContext,
    fragment: HasTypeCondition,
    type: GraphQLObjectType
) throws -> Bool {
    guard let typeConditionAST = fragment.getTypeCondition() else {
        return true
    }

    guard
        let conditionalType = typeFromAST(
            schema: exeContext.schema,
            inputTypeAST: typeConditionAST
        )
    else {
        return true
    }

    if
        let conditionalType = conditionalType as? GraphQLObjectType,
        conditionalType.name == type.name
    {
        return true
    }

    if let abstractType = conditionalType as? GraphQLAbstractType {
        return exeContext.schema.isSubType(
            abstractType: abstractType,
            maybeSubType: type
        )
    }

    return false
}

/**
 * Implements the logic to compute the key of a given field's entry
 */
func getFieldEntryKey(node: Field) -> String {
    return node.alias?.value ?? node.name.value
}

/**
 * Resolves the field on the given source object. In particular, this
 * figures out the value that the field returns by calling its resolve func,
 * then calls completeValue to complete promises, serialize scalars, or execute
 * the sub-selection-set for objects.
 */
public func resolveField(
    exeContext: ExecutionContext,
    parentType: GraphQLObjectType,
    source: any Sendable,
    fieldASTs: [Field],
    path: IndexPath
) async throws -> (any Sendable)? {
    let fieldAST = fieldASTs[0]
    let fieldName = fieldAST.name.value

    let fieldDef = try getFieldDef(
        schema: exeContext.schema,
        parentType: parentType,
        fieldName: fieldName
    )

    let returnType = fieldDef.type
    let resolve = fieldDef.resolve ?? defaultResolve

    // Build a Map object of arguments from the field.arguments AST, using the
    // variables scope to fulfill any variable references.
    // TODO: find a way to memoize, in case this field is within a List type.
    let args = try getArgumentValues(
        argDefs: fieldDef.args,
        argASTs: fieldAST.arguments,
        variables: exeContext.variableValues
    )

    // The resolve func's optional third argument is a context value that
    // is provided to every resolve func within an execution. It is commonly
    // used to represent an authenticated user, or request-specific caches.
    let context = exeContext.context

    // The resolve func's optional fourth argument is a collection of
    // information about the current execution state.
    let info = GraphQLResolveInfo(
        fieldName: fieldName,
        fieldASTs: fieldASTs,
        returnType: returnType,
        parentType: parentType,
        path: path,
        schema: exeContext.schema,
        fragments: exeContext.fragments,
        rootValue: exeContext.rootValue,
        operation: exeContext.operation,
        variableValues: exeContext.variableValues
    )

    // Get the resolve func, regardless of if its result is normal
    // or abrupt (error).
    let result = await resolveOrError(
        resolve: resolve,
        source: source,
        args: args,
        context: context,
        info: info
    )

    return try await completeValueCatchingError(
        exeContext: exeContext,
        returnType: returnType,
        fieldASTs: fieldASTs,
        info: info,
        path: path,
        result: result
    )
}

// Isolates the "ReturnOrAbrupt" behavior to not de-opt the `resolveField`
// function. Returns the result of `resolve` or the abrupt-return Error object.
func resolveOrError(
    resolve: GraphQLFieldResolve,
    source: any Sendable,
    args: Map,
    context: any Sendable,
    info: GraphQLResolveInfo
) async -> Result<(any Sendable)?, Error> {
    do {
        let result = try await resolve(source, args, context, info)
        return .success(result)
    } catch {
        return .failure(error)
    }
}

// This is a small wrapper around completeValue which detects and logs errors
// in the execution context.
func completeValueCatchingError(
    exeContext: ExecutionContext,
    returnType: GraphQLType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: Result<(any Sendable)?, Error>
) async throws -> (any Sendable)? {
    // If the field type is non-nullable, then it is resolved without any
    // protection from errors, however it still properly locates the error.
    if let returnType = returnType as? GraphQLNonNull {
        return try await completeValueWithLocatedError(
            exeContext: exeContext,
            returnType: returnType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )
    }

    // Otherwise, error protection is applied, logging the error and resolving
    // a null value for this field if one is encountered.
    do {
        return try await completeValueWithLocatedError(
            exeContext: exeContext,
            returnType: returnType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )
    } catch let error as GraphQLError {
        // If `completeValueWithLocatedError` returned abruptly (threw an error),
        // log the error and return .null.
        exeContext.append(error: error)
        return nil
    } catch {
        throw error
    }
}

// This is a small wrapper around completeValue which annotates errors with
// location information.
func completeValueWithLocatedError(
    exeContext: ExecutionContext,
    returnType: GraphQLType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: Result<(any Sendable)?, Error>
) async throws -> (any Sendable)? {
    do {
        return try await completeValue(
            exeContext: exeContext,
            returnType: returnType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )
    } catch {
        throw locatedError(
            originalError: error,
            nodes: fieldASTs,
            path: path
        )
    }
}

/**
 * Implements the instructions for completeValue as defined in the
 * "Field entries" section of the spec.
 *
 * If the field type is Non-Null, then this recursively completes the value
 * for the inner type. It throws a field error if that completion returns null,
 * as per the "Nullability" section of the spec.
 *
 * If the field type is a List, then this recursively completes the value
 * for the inner type on each item in the list.
 *
 * If the field type is a Scalar or Enum, ensures the completed value is a legal
 * value of the type by calling the `serialize` method of GraphQL type
 * definition.
 *
 * If the field is an abstract type, determine the runtime type of the value
 * and then complete based on that type
 *
 * Otherwise, the field type expects a sub-selection set, and will complete the
 * value by evaluating all sub-selections.
 */
func completeValue(
    exeContext: ExecutionContext,
    returnType: GraphQLType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: Result<(any Sendable)?, Error>
) async throws -> (any Sendable)? {
    switch result {
    case let .failure(error):
        throw error
    case let .success(result):
        // If field type is NonNull, complete for inner type, and throw field error
        // if result is nullish.
        if let returnType = returnType as? GraphQLNonNull {
            let value = try await completeValue(
                exeContext: exeContext,
                returnType: returnType.ofType,
                fieldASTs: fieldASTs,
                info: info,
                path: path,
                result: .success(result)
            )
            guard let value = value else {
                throw GraphQLError(
                    message: "Cannot return null for non-nullable field \(info.parentType.name).\(info.fieldName)."
                )
            }

            return value
        }

        // If result value is null-ish (nil or .null) then return .null.
        guard let result = result, let r = unwrap(result) else {
            return nil
        }

        // If field type is List, complete each item in the list with the inner type
        if let returnType = returnType as? GraphQLList {
            return try await completeListValue(
                exeContext: exeContext,
                returnType: returnType,
                fieldASTs: fieldASTs,
                info: info,
                path: path,
                result: r
            )
        }

        // If field type is a leaf type, Scalar or Enum, serialize to a valid value,
        // returning .null if serialization is not possible.
        if let returnType = returnType as? GraphQLLeafType {
            return try completeLeafValue(returnType: returnType, result: r)
        }

        // If field type is an abstract type, Interface or Union, determine the
        // runtime Object type and complete for that type.
        if let returnType = returnType as? GraphQLAbstractType {
            return try await completeAbstractValue(
                exeContext: exeContext,
                returnType: returnType,
                fieldASTs: fieldASTs,
                info: info,
                path: path,
                result: r
            )
        }

        // If field type is Object, execute and complete all sub-selections.
        if let returnType = returnType as? GraphQLObjectType {
            return try await completeObjectValue(
                exeContext: exeContext,
                returnType: returnType,
                fieldASTs: fieldASTs,
                info: info,
                path: path,
                result: r
            )
        }

        // Not reachable. All possible output types have been considered.
        throw GraphQLError(
            message: "Cannot complete value of unexpected type \"\(returnType)\"."
        )
    }
}

/**
 * Complete a list value by completing each item in the list with the
 * inner type
 */
func completeListValue(
    exeContext: ExecutionContext,
    returnType: GraphQLList,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: any Sendable
) async throws -> [(any Sendable)?] {
    guard let result = result as? [(any Sendable)?] else {
        throw GraphQLError(
            message:
            "Expected array, but did not find one for field " +
                "\(info.parentType.name).\(info.fieldName)."
        )
    }

    let itemType = returnType.ofType

    return try await withThrowingTaskGroup(of: (Int, (any Sendable)?).self) { group in
        // To preserve order, match size to result, and filter out nils at the end.
        var results: [(any Sendable)?] = result.map { _ in nil }
        for (index, item) in result.enumerated() {
            group.addTask {
                // No need to modify the info object containing the path,
                // since from here on it is not ever accessed by resolver funcs.
                let fieldPath = path.appending(index)

                let result = try await completeValueCatchingError(
                    exeContext: exeContext,
                    returnType: itemType,
                    fieldASTs: fieldASTs,
                    info: info,
                    path: fieldPath,
                    result: .success(item)
                )
                return (index, result)
            }
            for try await result in group {
                results[result.0] = result.1
            }
        }
        return results.compactMap { $0 }
    }
}

/**
 * Complete a Scalar or Enum by serializing to a valid value, returning
 * .null if serialization is not possible.
 */
func completeLeafValue(returnType: GraphQLLeafType, result: (any Sendable)?) throws -> Map {
    guard let result = result else {
        return .null
    }
    let serializedResult = try returnType.serialize(value: result)

    // Do not check for serialization to null here. Some scalars may model literals as `Map.null`.

    return serializedResult
}

/**
 * Complete a value of an abstract type by determining the runtime object type
 * of that value, then complete the value for that type.
 */
func completeAbstractValue(
    exeContext: ExecutionContext,
    returnType: GraphQLAbstractType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: any Sendable
) async throws -> (any Sendable)? {
    var resolveRes = try returnType.resolveType?(result, info)
        .typeResolveResult

    resolveRes = try resolveRes ?? defaultResolveType(
        value: result,
        info: info,
        abstractType: returnType
    )

    guard let resolveResult = resolveRes else {
        throw GraphQLError(
            message: "Could not find a resolve function.",
            nodes: fieldASTs
        )
    }

    // If resolveType returns a string, we assume it's a GraphQLObjectType name.
    var runtimeType: GraphQLType?

    switch resolveResult {
    case let .name(name):
        runtimeType = exeContext.schema.getType(name: name)
    case let .type(type):
        runtimeType = type
    }

    guard let objectType = runtimeType as? GraphQLObjectType else {
        throw GraphQLError(
            message:
            "Abstract type \(returnType.name) must resolve to an Object type at " +
                "runtime for field \(info.parentType.name).\(info.fieldName) with " +
                "value \"\(resolveResult)\", received \"\(String(describing: runtimeType))\".",
            nodes: fieldASTs
        )
    }

    if !exeContext.schema.isSubType(abstractType: returnType, maybeSubType: objectType) {
        throw GraphQLError(
            message:
            "Runtime Object type \"\(objectType.name)\" is not a possible type " +
                "for \"\(returnType.name)\".",
            nodes: fieldASTs
        )
    }

    return try await completeObjectValue(
        exeContext: exeContext,
        returnType: objectType,
        fieldASTs: fieldASTs,
        info: info,
        path: path,
        result: result
    )
}

/**
 * Complete an Object value by executing all sub-selections.
 */
func completeObjectValue(
    exeContext: ExecutionContext,
    returnType: GraphQLObjectType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: IndexPath,
    result: any Sendable
) async throws -> (any Sendable)? {
    // If there is an isTypeOf predicate func, call it with the
    // current result. If isTypeOf returns false, then raise an error rather
    // than continuing execution.
    if
        let isTypeOf = returnType.isTypeOf,
        try !isTypeOf(result, info)
    {
        throw GraphQLError(
            message:
            "Expected value of type \"\(returnType.name)\" but got: \(result).",
            nodes: fieldASTs
        )
    }

    // Collect sub-fields to execute to complete this value.
    var subFieldASTs: OrderedDictionary<String, [Field]> = [:]
    var visitedFragmentNames: [String: Bool] = [:]

    for fieldAST in fieldASTs {
        if let selectionSet = fieldAST.selectionSet {
            subFieldASTs = try collectFields(
                exeContext: exeContext,
                runtimeType: returnType,
                selectionSet: selectionSet,
                fields: &subFieldASTs,
                visitedFragmentNames: &visitedFragmentNames
            )
        }
    }

    return try await exeContext.queryStrategy.executeFields(
        exeContext: exeContext,
        parentType: returnType,
        sourceValue: result,
        path: path,
        fields: subFieldASTs
    )
}

/**
 * If a resolveType func is not given, then a default resolve behavior is
 * used which tests each possible type for the abstract type by calling
 * isTypeOf for the object being coerced, returning the first type that matches.
 */
func defaultResolveType(
    value: any Sendable,
    info: GraphQLResolveInfo,
    abstractType: GraphQLAbstractType
) throws -> TypeResolveResult? {
    let possibleTypes = info.schema.getPossibleTypes(abstractType: abstractType)

    guard
        let type = try possibleTypes
            .find({ try $0.isTypeOf?(value, info) ?? false })
    else {
        return nil
    }

    return .type(type)
}

/**
 * If a resolve func is not given, then a default resolve behavior is used
 * which takes the property of the source object of the same name as the field
 * and returns it as the result.
 */
func defaultResolve(
    source: any Sendable,
    args _: Map,
    context _: any Sendable,
    info: GraphQLResolveInfo
) async throws -> (any Sendable)? {
    guard let source = unwrap(source) else {
        return nil
    }

    if let subscriptable = source as? KeySubscriptable {
        let value = subscriptable[info.fieldName]
        return value
    }
    if let subscriptable = source as? [String: any Sendable] {
        let value = subscriptable[info.fieldName]
        return value
    }
    if let subscriptable = source as? OrderedDictionary<String, any Sendable> {
        let value = subscriptable[info.fieldName]
        return value
    }

    let mirror = Mirror(reflecting: source)
    guard let value = mirror.getValue(named: info.fieldName) else {
        return nil
    }
    return value
}

/**
 * This method looks up the field on the given type defintion.
 * It has special casing for the two introspection fields, __schema
 * and __typename. __typename is special because it can always be
 * queried as a field, even in situations where no other fields
 * are allowed, like on a Union. __schema could get automatically
 * added to the query type, but that would require mutating type
 * definitions, which would cause issues.
 */
func getFieldDef(
    schema: GraphQLSchema,
    parentType: GraphQLObjectType,
    fieldName: String
) throws -> GraphQLFieldDefinition {
    if fieldName == SchemaMetaFieldDef.name, schema.queryType?.name == parentType.name {
        return SchemaMetaFieldDef
    } else if fieldName == TypeMetaFieldDef.name, schema.queryType?.name == parentType.name {
        return TypeMetaFieldDef
    } else if fieldName == TypeNameMetaFieldDef.name {
        return TypeNameMetaFieldDef
    }

    // This field should exist because we passed validation before execution
    guard let fieldDefinition = try parentType.getFields()[fieldName] else {
        throw GraphQLError(
            message: "Expected field definition not found: '\(fieldName)' on '\(parentType.name)'"
        )
    }
    return fieldDefinition
}
