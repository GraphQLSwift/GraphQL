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
final class ExecutionContext {
  let schema: GraphQLSchema
  let fragments: [String: FragmentDefinition]
  let rootValue: Any
  let contextValue: Any
  let operation: OperationDefinition
  let variableValues: [String: Map]
  var errors: [GraphQLError]

    init(
        schema: GraphQLSchema,
        fragments: [String: FragmentDefinition],
        rootValue: Any,
        contextValue: Any,
        operation: OperationDefinition,
        variableValues: [String: Map],
        errors: [GraphQLError]
    ) {
        self.schema = schema
        self.fragments = fragments
        self.rootValue = rootValue
        self.contextValue = contextValue
        self.operation = operation
        self.variableValues = variableValues
        self.errors = errors

    }
}

/**
 * Implements the "Evaluating requests" section of the GraphQL specification.
 *
 * If the arguments to this func do not result in a legal execution context,
 * a GraphQLError will be thrown immediately explaining the invalid input.
 */
func execute(
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: Any,
    contextValue: Any,
    variableValues: [String: Map] = [:],
    operationName: String? = nil
) throws -> Map {
    // If a valid context cannot be created due to incorrect arguments,
    // this will throw an error.
    let context = try buildExecutionContext(
        schema: schema,
        documentAST: documentAST,
        rootValue: rootValue,
        contextValue: contextValue,
        rawVariableValues: variableValues,
        operationName: operationName
    )

    do {
        let data = try executeOperation(
            exeContext: context,
            operation: context.operation,
            rootValue: rootValue
        )

        var dataMap: Map = [:]

        for (key, value) in data {
            dataMap[key] = try map(from: value)
        }

        var result: [String: Map] = ["data": dataMap]

        if !context.errors.isEmpty {
            result["errors"] = context.errors.map
        }

        return .dictionary(result)
    } catch let error as GraphQLError {
        return ["errors": [error].map]
    }
}

/**
 * Constructs a ExecutionContext object from the arguments passed to
 * execute, which we will pass throughout the other execution methods.
 *
 * Throws a GraphQLError if a valid execution context cannot be created.
 */
func buildExecutionContext(
    schema: GraphQLSchema,
    documentAST: Document,
    rootValue: Any,
    contextValue: Any,
    rawVariableValues: [String: Map],
    operationName: String?
) throws -> ExecutionContext {
    let errors: [GraphQLError] = []
    var possibleOperation: OperationDefinition? = nil
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
        schema: schema,
        fragments: fragments,
        rootValue: rootValue,
        contextValue: contextValue,
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
    rootValue: Any
) throws -> [String : Any] {
    let type = try getOperationRootType(schema: exeContext.schema, operation: operation)

    var inputFields: [String : [Field]] = [:]
    var visitedFragmentNames: [String : Bool] = [:]

    let fields = try collectFields(
        exeContext: exeContext,
        runtimeType: type,
        selectionSet: operation.selectionSet,
        fields: &inputFields,
        visitedFragmentNames: &visitedFragmentNames
    )

    let path: [IndexPathElement] = []

    if operation.operation == .mutation {
        return try executeFieldsSerially(
            exeContext: exeContext,
            parentType: type,
            sourceValue: rootValue,
            path: path,
            fields: fields
        )
    }

    return try executeFields(
        exeContext: exeContext,
        parentType: type,
        sourceValue: rootValue,
        path: path,
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
      return schema.queryType
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
 * Implements the "Evaluating selection sets" section of the spec
 * for "write" mode.
 */
func executeFieldsSerially(
    exeContext: ExecutionContext,
    parentType: GraphQLObjectType,
    sourceValue: Any,
    path: [IndexPathElement],
    fields: [String: [Field]]
) throws -> [String: Any] {
    return try fields.reduce([:]) { results, field in
        var results = results
        let fieldASTs = field.value
        let fieldPath = path + [field.key] as [IndexPathElement]

        let result = try resolveField(
            exeContext: exeContext,
            parentType: parentType,
            source: sourceValue,
            fieldASTs: fieldASTs,
            path: fieldPath
        )

        results[field.key] = result ?? Map.null
        return results
    }
}

/**
 * Implements the "Evaluating selection sets" section of the spec
 * for "read" mode.
 */
func executeFields(
    exeContext: ExecutionContext,
    parentType: GraphQLObjectType,
    sourceValue: Any,
    path: [IndexPathElement],
    fields: [String: [Field]]
) throws -> [String : Any] {
    return try executeFieldsSerially(
        exeContext: exeContext,
        parentType: parentType,
        sourceValue: sourceValue,
        path: path,
        fields: fields
    )
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
    fields: inout [String: [Field]],
    visitedFragmentNames: inout [String: Bool]
) throws -> [String: [Field]] {
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

            guard shouldInclude && fragmentConditionMatches else {
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

            guard visitedFragmentNames[fragmentName] == nil && shouldInclude else {
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
            variableValues: exeContext.variableValues
        )

        if skip["if"] == .bool(true) {
            return false
        }
    }

    if let includeAST = directives.find({ $0.name.value == GraphQLIncludeDirective.name }) {
        let include = try getArgumentValues(
            argDefs: GraphQLIncludeDirective.args,
            argASTs: includeAST.arguments,
            variableValues: exeContext.variableValues
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

    guard let conditionalType = typeFromAST(schema: exeContext.schema, inputTypeAST: typeConditionAST) else {
        return true
    }

    if let conditionalType = conditionalType as? GraphQLObjectType, conditionalType.name == type.name {
        return true
    }

    if let abstractType = conditionalType as? GraphQLAbstractType {
        return try exeContext.schema.isPossibleType(abstractType: abstractType, possibleType: type)
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
func resolveField(
    exeContext: ExecutionContext,
    parentType: GraphQLObjectType,
    source: Any,
    fieldASTs: [Field],
    path: [IndexPathElement]
) throws -> Any? {
    let fieldAST = fieldASTs[0]
    let fieldName = fieldAST.name.value

    let fieldDef = getFieldDef(
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
        variableValues: exeContext.variableValues
    )

    // The resolve func's optional third argument is a context value that
    // is provided to every resolve func within an execution. It is commonly
    // used to represent an authenticated user, or request-specific caches.
    let context = exeContext.contextValue

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
    let result = resolveOrError(
        resolve: resolve,
        source: source,
        args: args,
        context: context,
        info: info
    )
    
    return try completeValueCatchingError(
        exeContext: exeContext,
        returnType: returnType,
        fieldASTs: fieldASTs,
        info: info,
        path: path,
        result: result
    )
}

enum ResultOrError {
    case result(Any?)
    case error(Error)
}

// Isolates the "ReturnOrAbrupt" behavior to not de-opt the `resolveField`
// function. Returns the result of `resolve` or the abrupt-return Error object.
func resolveOrError(
    resolve: GraphQLFieldResolve,
    source: Any,
    args: Map,
    context: Any,
    info: GraphQLResolveInfo
)-> ResultOrError {
    do {
        return try .result(resolve(source, args, context, info))
    } catch {
        return .error(error)
    }
}

// This is a small wrapper around completeValue which detects and logs errors
// in the execution context.
func completeValueCatchingError(
    exeContext: ExecutionContext,
    returnType: GraphQLType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: [IndexPathElement],
    result: ResultOrError
) throws -> Any? {
    // If the field type is non-nullable, then it is resolved without any
    // protection from errors, however it still properly locates the error.
    if let returnType = returnType as? GraphQLNonNull {
        return try completeValueWithLocatedError(
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
        let completed = try completeValueWithLocatedError(
            exeContext: exeContext,
            returnType: returnType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )

        return completed
    } catch let error as GraphQLError {
        // If `completeValueWithLocatedError` returned abruptly (threw an error),
        // log the error and return .null.
        exeContext.errors.append(error)
        return nil
    } catch {
        fatalError()
    }
}

// This is a small wrapper around completeValue which annotates errors with
// location information.
func completeValueWithLocatedError(
    exeContext: ExecutionContext,
    returnType: GraphQLType,
    fieldASTs: [Field],
    info: GraphQLResolveInfo,
    path: [IndexPathElement],
    result: ResultOrError
) throws -> Any? {
    do {
        let completed = try completeValue(
            exeContext: exeContext,
            returnType: returnType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )

        return completed
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
    path: [IndexPathElement],
    result: ResultOrError
) throws -> Any? {
    switch result {
    case .error(let error):
        throw error
    case .result(let result):
        // If field type is NonNull, complete for inner type, and throw field error
        // if result is nullish.
        if let returnType = returnType as? GraphQLNonNull {
            let completed = try completeValue(
                exeContext: exeContext,
                returnType: returnType.ofType,
                fieldASTs: fieldASTs,
                info: info,
                path: path,
                result: .result(result)
            )

            guard let reallyCompleted = completed else {
                throw GraphQLError(
                    message: "Cannot return null for non-nullable field \(info.parentType.name).\(info.fieldName)."
                )
            }

            return reallyCompleted
        }

        // If result value is null-ish (nil or .null) then return .null.
        guard let res = result, let r = unwrap(res) else {
            return nil
        }

        // If field type is List, complete each item in the list with the inner type
        if let returnType = returnType as? GraphQLList {
            return try completeListValue(
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
            return try completeAbstractValue(
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
            return try completeObjectValue(
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
    path: [IndexPathElement],
    result: Any
) throws -> Any? {
    guard let result = result as? [Any?] else {
        throw GraphQLError(
            message:
            "Expected array, but did not find one for field " +
            "\(info.parentType.name).\(info.fieldName)."
        )
    }

    let itemType = returnType.ofType
    var completedResults: [Any?] = []

    for (index, item) in result.enumerated() {
        // No need to modify the info object containing the path,
        // since from here on it is not ever accessed by resolver funcs.
        let fieldPath = path + [index] as [IndexPathElement]

        let completedItem = try completeValueCatchingError(
            exeContext: exeContext,
            returnType: itemType,
            fieldASTs: fieldASTs,
            info: info,
            path: fieldPath,
            result: .result(item)
        )

        completedResults.append(completedItem)
    }
    
    return completedResults
}

/**
 * Complete a Scalar or Enum by serializing to a valid value, returning
 * .null if serialization is not possible.
 */
func completeLeafValue(returnType: GraphQLLeafType, result: Any?) throws -> Map {
    // TODO: check this out
    guard let result = result else {
        return .null
    }

    let serializedResult = try returnType.serialize(value: result)

    if serializedResult == .null {
        throw GraphQLError(
            message:
            "Expected a value of type \"\(returnType)\" but " +
            "received: \(result)"
        )
    }
    
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
    path: [IndexPathElement],
    result: Any
) throws -> Any? {
    var resolveRes = try returnType.resolveType?(result, exeContext.contextValue, info).typeResolveResult

    resolveRes = try resolveRes ?? defaultResolveType(
        value: result,
        context: exeContext.contextValue,
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
    case .name(let name):
        runtimeType = exeContext.schema.getType(name: name)
    case .type(let type):
        runtimeType = type
    }

    guard let objectType = runtimeType as? GraphQLObjectType else {
        throw GraphQLError(
            message:
            "Abstract type \(returnType.name) must resolve to an Object type at " +
            "runtime for field \(info.parentType.name).\(info.fieldName) with " +
            "value \"\(resolveResult)\", received \"\(runtimeType)\".",
            nodes: fieldASTs
        )
    }

    if try !exeContext.schema.isPossibleType(abstractType: returnType, possibleType: objectType) {
        throw GraphQLError(
            message:
            "Runtime Object type \"\(objectType.name)\" is not a possible type " +
            "for \"\(returnType.name)\".",
            nodes: fieldASTs
        )
    }

    return try completeObjectValue(
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
    path: [IndexPathElement],
    result: Any
) throws -> Any? {
    // If there is an isTypeOf predicate func, call it with the
    // current result. If isTypeOf returns false, then raise an error rather
    // than continuing execution.
    guard try returnType.isTypeOf?(result, exeContext.contextValue, info) ?? true else {
        throw GraphQLError(
            message:
            "Expected value of type \"\(returnType.name)\" but got: \(result).",
            nodes: fieldASTs
        )
    }

    // Collect sub-fields to execute to complete this value.
    var subFieldASTs: [String: [Field]] = [:]
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
    
    return try executeFields(
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
    value: Any,
    context: Any,
    info: GraphQLResolveInfo,
    abstractType: GraphQLAbstractType
) throws -> TypeResolveResult? {
    let possibleTypes = info.schema.getPossibleTypes(abstractType: abstractType)

    guard let type = try possibleTypes.find({ try $0.isTypeOf?(value, context, info) ?? false }) else {
        return nil
    }

    return .type(type)
}

/**
 * If a resolve func is not given, then a default resolve behavior is used
 * which takes the property of the source object of the same name as the field
 * and returns it as the result.
 */
func defaultResolve(source: Any, args: Map, context: Any, info: GraphQLResolveInfo) -> Any? {    
    guard let source = unwrap(source) else {
        return nil
    }

    guard let s = source as? MapFallibleRepresentable else {
        return nil
    }

    // TODO: check why Reflection fails
    guard let value = try? get(info.fieldName, from: s) else {
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
) -> GraphQLFieldDefinition {
    if fieldName == SchemaMetaFieldDef.name && schema.queryType.name == parentType.name {
        return SchemaMetaFieldDef
    } else if fieldName == TypeMetaFieldDef.name && schema.queryType.name == parentType.name {
        return TypeMetaFieldDef
    } else if fieldName == TypeNameMetaFieldDef.name {
        return TypeNameMetaFieldDef
    }

    // we know this field exists because we passed validation before execution
    return parentType.fields[fieldName]!
}
