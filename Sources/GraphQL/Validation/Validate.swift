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
 * @internal
 */
func validateSDL(
    documentAST: Document,
    schemaToExtend: GraphQLSchema? = nil,
    rules: [SDLValidationRule] = specifiedSDLRules
) -> [GraphQLError] {
    var errors: [GraphQLError] = []
    let context = SDLValidationContext(
        ast: documentAST,
        schema: schemaToExtend
    ) { error in
        errors.append(error)
    }

    let visitors = rules.map { rule in
        rule(context)
    }
    visit(root: documentAST, visitor: visitInParallel(visitors: visitors))
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

/**
 * Utility function which asserts a SDL document is valid by throwing an error
 * if it is invalid.
 *
 * @internal
 */
func assertValidSDL(documentAST: Document) throws {
    let errors = validateSDL(documentAST: documentAST)
    if !errors.isEmpty {
        throw GraphQLError(
            message: errors.map { $0.message }.joined(separator: "\n\n"),
            locations: []
        )
    }
}

/**
 * Utility function which asserts a SDL document is valid by throwing an error
 * if it is invalid.
 *
 * @internal
 */
func assertValidSDLExtension(
    documentAST: Document,
    schema: GraphQLSchema
) throws {
    let errors = validateSDL(documentAST: documentAST, schemaToExtend: schema)
    if !errors.isEmpty {
        throw GraphQLError(
            message: errors.map { $0.message }.joined(separator: "\n\n"),
            locations: []
        )
    }
}
