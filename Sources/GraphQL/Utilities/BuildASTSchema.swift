/**
 * This takes the ast of a schema document produced by the parse function in
 * src/language/parser.js.
 *
 * If no schema definition is provided, then it will look for types named Query,
 * Mutation and Subscription.
 *
 * Given that AST it constructs a GraphQLSchema. The resulting schema
 * has no resolve methods, so execution will use default resolvers.
 */
public func buildASTSchema(
    documentAST: Document,
    assumeValid: Bool = false,
    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
    if assumeValid != true, !assumeValidSDL {
        try assertValidSDL(documentAST: documentAST)
    }
    let emptySchemaConfig = GraphQLSchemaNormalizedConfig()
    let config = try extendSchemaImpl(emptySchemaConfig, documentAST)

    if config.astNode == nil {
        try config.types.forEach { type in
            switch type.name {
            case "Query": config.query = try checkOperationType(operationType: .query, type: type)
            case "Mutation": config
                .mutation = try checkOperationType(operationType: .mutation, type: type)
            case "Subscription": config
                .subscription = try checkOperationType(operationType: .subscription, type: type)
            default: break
            }
        }
    }

    var directives = config.directives
    directives.append(contentsOf: specifiedDirectives.filter { stdDirective in
        config.directives.allSatisfy { directive in
            directive.name != stdDirective.name
        }
    })

    config.directives = directives

    return try GraphQLSchema(config: config)
}

/**
 * A helper function to build a GraphQLSchema directly from a source
 * document.
 */
public func buildSchema(
    source: Source,
    assumeValid: Bool = false,
    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
    let document = try parse(
        source: source
    )

    return try buildASTSchema(
        documentAST: document,
        assumeValid: assumeValid,
        assumeValidSDL: assumeValidSDL
    )
}

/**
 * A helper function to build a GraphQLSchema directly from a source
 * document.
 */
public func buildSchema(
    source: String,
    assumeValid: Bool = false,
    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
    let document = try parse(
        source: source
    )

    return try buildASTSchema(
        documentAST: document,
        assumeValid: assumeValid,
        assumeValidSDL: assumeValidSDL
    )
}
