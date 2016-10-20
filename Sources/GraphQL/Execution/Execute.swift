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
  let rootValue: Map
  let contextValue: Map
  let operation: OperationDefinition
  let variableValues: [String: Map]
  var errors: [GraphQLError]

    init(schema: GraphQLSchema, fragments: [String: FragmentDefinition], rootValue: Map, contextValue: Map, operation: OperationDefinition, variableValues: [String: Map], errors: [GraphQLError]) {
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
 * Returns a Promise that will eventually be resolved and never rejected.
 *
 * If the arguments to this func do not result in a legal execution context,
 * a GraphQLError will be thrown immediately explaining the invalid input.
 */
func execute(schema: GraphQLSchema, documentAST: Document, rootValue: Map, contextValue: Map, variableValues: [String: Map] = [:], operationName: String? = nil) throws -> Map {

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

        return ["data": data]
    } catch let error as GraphQLError {
        return ["error": [error].map]
    }
}

/**
 * Constructs a ExecutionContext object from the arguments passed to
 * execute, which we will pass throughout the other execution methods.
 *
 * Throws a GraphQLError if a valid execution context cannot be created.
 */
func buildExecutionContext(schema: GraphQLSchema, documentAST: Document, rootValue: Map, contextValue: Map, rawVariableValues: [String: Map], operationName: String?) throws -> ExecutionContext {
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
func executeOperation(exeContext: ExecutionContext, operation: OperationDefinition, rootValue: Map) throws -> Map {
    let type = try getOperationRootType(schema: exeContext.schema, operation: operation)

    let fields = try collectFields(
        exeContext: exeContext,
        runtimeType: type,
        selectionSet: operation.selectionSet,
        fields: [:],
        visitedFragmentNames: [:]
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
func getOperationRootType(schema: GraphQLSchema, operation: OperationDefinition) throws -> GraphQLObjectType {
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
//    default:
//      throw GraphQLError(
//        message: "Can only execute queries, mutations and subscriptions",
//        nodes: [operation]
//      )
  }
}

/**
 * Implements the "Evaluating selection sets" section of the spec
 * for "write" mode.
 */
func executeFieldsSerially(exeContext: ExecutionContext, parentType: GraphQLObjectType, sourceValue: Map, path: [IndexPathElement], fields: [String: [Field]]) throws -> Map {
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

        guard let r = result else {
            return results
        }

        results[field.key] = r
        
        return results
    }
}

/**
 * Implements the "Evaluating selection sets" section of the spec
 * for "read" mode.
 */
func executeFields(exeContext: ExecutionContext, parentType: GraphQLObjectType, sourceValue: Map,
                   path: [IndexPathElement], fields: [String: [Field]]) throws -> Map {
    let finalResults: [String: Map] = try fields.reduce([:]) { results, field in
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

        guard let r = result else {
            return results
        }

        results[field.key] = r
        
        return results
    }
    
    return .dictionary(finalResults)
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
func collectFields(exeContext: ExecutionContext, runtimeType: GraphQLObjectType, selectionSet: SelectionSet, fields: [String: [Field]],
  visitedFragmentNames: [String: Bool]) throws -> [String: [Field]] {
    var fields = fields
    var visitedFragmentNames = visitedFragmentNames

    for selection in selectionSet.selections {
    switch selection {
      case let selection as Field:
        if try !shouldIncludeNode(exeContext: exeContext, directives: selection.directives) {
          continue
        }

        let name = getFieldEntryKey(node: selection)

        if fields[name] == nil {
          fields[name] = []
        }

        fields[name]?.append(selection)
      case let selection as InlineFragment:
        if try !shouldIncludeNode(exeContext: exeContext, directives: selection.directives) ||
           !doesFragmentConditionMatch(exeContext: exeContext, fragment: selection, type: runtimeType) {
          continue
        }

        try collectFields(
            exeContext: exeContext,
            runtimeType: runtimeType,
            selectionSet: selection.selectionSet,
            fields: fields,
            visitedFragmentNames: visitedFragmentNames
        )

      case let selection as FragmentSpread:
        let fragName = selection.name.value

        if try visitedFragmentNames[fragName] != nil ||
            !shouldIncludeNode(exeContext: exeContext, directives: selection.directives) {
          continue
        }

        visitedFragmentNames[fragName] = true
        guard let fragment = exeContext.fragments[fragName] else {
            continue
        }

        if !doesFragmentConditionMatch(exeContext: exeContext, fragment: fragment, type: runtimeType) {
          continue
        }

        try collectFields(
            exeContext: exeContext,
            runtimeType: runtimeType,
            selectionSet: fragment.selectionSet,
            fields: fields,
            visitedFragmentNames: visitedFragmentNames
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
        let skipIf = try getArgumentValues(
            argDefs: GraphQLSkipDirective.args,
            argASTs: skipAST.arguments,
            variableValues: exeContext.variableValues
        )["if"]

        if let skipIf = skipIf, skipIf == .bool(true) {
            return false
        }
    }

    if let includeAST = directives.find({ $0.name.value == GraphQLIncludeDirective.name }) {
        let includeIf = try getArgumentValues(
            argDefs: GraphQLIncludeDirective.args,
            argASTs: includeAST.arguments,
            variableValues: exeContext.variableValues
        )["if"]

        if let includeIf = includeIf, includeIf == .bool(false) {
            return false
        }
    }
    
    return true
}

/**
 * Determines if a fragment is applicable to the given type.
 */
func doesFragmentConditionMatch(exeContext: ExecutionContext, fragment: HasTypeCondition, type: GraphQLObjectType) -> Bool {
    guard let typeConditionAST = fragment.getTypeCondition() else {
        return true
    }

    guard let conditionalType = typeFromAST(schema: exeContext.schema, inputTypeAST: typeConditionAST) else {
        return true
    }

    if let abstractType = conditionalType as? GraphQLAbstractType {
        return exeContext.schema.isPossibleType(abstractType: abstractType, possibleType: type)
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
func resolveField(exeContext: ExecutionContext, parentType: GraphQLObjectType, source: Map,
                  fieldASTs: [Field], path: [IndexPathElement]) throws -> Map? {
    let fieldAST = fieldASTs[0]
    let fieldName = fieldAST.name.value

    guard let fieldDef = getFieldDef(schema: exeContext.schema, parentType: parentType, fieldName: fieldName) else {
        return nil // TODO: this used to be "undefined"
    }

    let returnType = fieldDef.type
    let resolve = fieldDef.resolve ?? defaultResolve

    // Build a JS object of arguments from the field.arguments AST, using the
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
    let result = try resolve(source, args, context, info)
    
    return try completeValueCatchingError(
        exeContext: exeContext,
        returnType: returnType,
        fieldASTs: fieldASTs,
        info: info,
        path: path,
        result: result
    )
}

// This is a small wrapper around completeValue which detects and logs errors
// in the execution context.
func completeValueCatchingError(exeContext: ExecutionContext, returnType: GraphQLType, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map? {
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
        // log the error and return null.
        exeContext.errors.append(error)
        return .null // TODO: this was nil before
    } catch {
        fatalError()
    }
}

// This is a small wrapper around completeValue which annotates errors with
// location information.
func completeValueWithLocatedError(exeContext: ExecutionContext, returnType: GraphQLType, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map? {
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
        throw locatedError(originalError: error, nodes: fieldASTs, path: path)
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
func completeValue(exeContext: ExecutionContext, returnType: GraphQLType, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map? {
    // If field type is NonNull, complete for inner type, and throw field error
    // if result is null.
    if let returnType = returnType as? GraphQLNonNull {
        let completed = try completeValue(
            exeContext: exeContext,
            returnType: returnType.ofType,
            fieldASTs: fieldASTs,
            info: info,
            path: path,
            result: result
        )

        guard let c = completed else {
            throw GraphQLError(
                message: "Cannot return null for non-nullable field \(info.parentType.name).\(info.fieldName)."
            )
        }

        return c
    }

    // If result value is null-ish (null, undefined, or NaN) then return null.
    if isNullish(result) {
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
            result: result
        )
    }

    // If field type is a leaf type, Scalar or Enum, serialize to a valid value,
    // returning null if serialization is not possible.
    if let returnType = returnType as? GraphQLLeafType {
        return try completeLeafValue(returnType: returnType, result: result)
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
            result: result
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
            result: result
        )
    }
    
    // Not reachable. All possible output types have been considered.
    throw GraphQLError(
        message: "Cannot complete value of unexpected type \"\(returnType)\"."
    )
}

/**
 * Complete a list value by completing each item in the list with the
 * inner type
 */
func completeListValue(exeContext: ExecutionContext, returnType: GraphQLList, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map? {
    guard case .array(let result) = result else {
        throw GraphQLError(
            message:
            "Expected Iterable, but did not find one for field " +
            "\(info.parentType.name).\(info.fieldName)."
        )
    }

    let itemType = returnType.ofType
    var completedResults: [Map] = []

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
            result: item
        )

        guard let c = completedItem else {
            return nil
        }

        completedResults.append(c)
    }
    
    return .array(completedResults)
}

/**
 * Complete a Scalar or Enum by serializing to a valid value, returning
 * null if serialization is not possible.
 */
func completeLeafValue(returnType: GraphQLLeafType, result: Map) throws -> Map {
    let serializedResult = try returnType.serialize(value: result)

    if isNullish(serializedResult) {
        throw GraphQLError(
            message:
            "Expected a value of type \"\(returnType)\" but " +
            "received: \(result)"
        )
    }
    
    return serializedResult!
}

/**
 * Complete a value of an abstract type by determining the runtime object type
 * of that value, then complete the value for that type.
 */
func completeAbstractValue(exeContext: ExecutionContext, returnType: GraphQLAbstractType, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map {
    let resolveRes = try returnType.resolveType?(result, exeContext.contextValue, info) ??
        defaultResolveType(value: result, context: exeContext.contextValue, info: info, abstractType: returnType).map({ .type($0) })

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

    if !exeContext.schema.isPossibleType(abstractType: returnType, possibleType: objectType) {
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
func completeObjectValue(exeContext: ExecutionContext, returnType: GraphQLObjectType, fieldASTs: [Field], info: GraphQLResolveInfo, path: [IndexPathElement], result: Map) throws -> Map {
    // If there is an isTypeOf predicate func, call it with the
    // current result. If isTypeOf returns false, then raise an error rather
    // than continuing execution.
    if returnType.isTypeOf?(result, exeContext.contextValue, info) ?? false {
        throw GraphQLError(
            message:
            "Expected value of type \"\(returnType.name)\" but got: \(result).",
            nodes: fieldASTs
        )
    }

    // Collect sub-fields to execute to complete this value.
    var subFieldASTs: [String: [Field]] = [:]
    let visitedFragmentNames: [String: Bool] = [:]

    for fieldAST in fieldASTs {
        if let selectionSet = fieldAST.selectionSet {
            subFieldASTs = try collectFields(
                exeContext: exeContext,
                runtimeType: returnType,
                selectionSet: selectionSet,
                fields: subFieldASTs,
                visitedFragmentNames: visitedFragmentNames
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
func defaultResolveType(value: Map, context: Map, info: GraphQLResolveInfo, abstractType: GraphQLAbstractType) -> GraphQLObjectType? {
    let possibleTypes = info.schema.getPossibleTypes(abstractType: abstractType)
    return possibleTypes.find({ $0.isTypeOf?(value, context, info) ?? false })
}

/**
 * If a resolve func is not given, then a default resolve behavior is used
 * which takes the property of the source object of the same name as the field
 * and returns it as the result, or if it's a func, returns the result
 * of calling that func while passing along args and context.
 */
func defaultResolve(source: Map, args: [String: Map], context: Map, info: GraphQLResolveInfo) -> Map {
  // ensure source is a value for which property access is acceptable.
    if case .dictionary(let source) = source {
    let property = source[info.fieldName]

        // TODO: Dynamic Shit
//    if (typeof property === 'func') {
//      return source[info.fieldName](args, context)
//    }

    return property!
  }

    return .null
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
func getFieldDef(schema: GraphQLSchema, parentType: GraphQLObjectType, fieldName: String) -> GraphQLFieldDefinition? {
//  if (fieldName === schemaMetaFieldDef.name &&
//      schema.getQueryType() === parentType) {
//    return SchemaMetaFieldDef
//  } else if (fieldName === typeMetaFieldDef.name &&
//             schema.getQueryType() === parentType) {
//    return TypeMetaFieldDef
//  } else if (fieldName === typeNameMetaFieldDef.name) {
//    return TypeNameMetaFieldDef
//  }
  return parentType.fields[fieldName]
}
