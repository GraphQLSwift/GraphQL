/**
 * Given a GraphQL source, parses it into a Document.
 * Throws GraphQLError if a syntax error is encountered.
 */
func parse(
    instrumentation: Instrumentation = NoOpInstrumentation,
    source: String,
    noLocation: Bool = false
) throws -> Document {
    return try parse(
        instrumentation: instrumentation,
        source: Source(body: source),
        noLocation: noLocation
    )
}

/**
 * Given a GraphQL source, parses it into a Document.
 * Throws GraphQLError if a syntax error is encountered.
 */
public func parse(
    instrumentation: Instrumentation = NoOpInstrumentation,
    source: Source,
    noLocation: Bool = false
) throws -> Document {
    let started = instrumentation.now
    do {
        let lexer = createLexer(source: source, noLocation: noLocation)
        let document = try parseDocument(lexer: lexer)
        instrumentation.queryParsing(
            processId: processId(),
            threadId: threadId(),
            started: started,
            finished: instrumentation.now,
            source: source,
            result: .result(document)
        )
        return document
    } catch let error as GraphQLError {
        instrumentation.queryParsing(
            processId: processId(),
            threadId: threadId(),
            started: started,
            finished: instrumentation.now,
            source: source,
            result: .error(error)
        )
        throw error
    }
}

/**
 * Given a string containing a GraphQL value (ex. `[42]`), parse the AST for
 * that value.
 * Throws GraphQLError if a syntax error is encountered.
 *
 * This is useful within tools that operate upon GraphQL Values directly and
 * in isolation of complete GraphQL documents.
 *
 * Consider providing the results to the utility func: valueFromAST().
 */
func parseValue(source: String, noLocation: Bool = false) throws -> Value {
    return try parseValue(source: Source(body: source), noLocation: noLocation)
}

/**
 * Given a string containing a GraphQL value (ex. `[42]`), parse the AST for
 * that value.
 * Throws GraphQLError if a syntax error is encountered.
 *
 * This is useful within tools that operate upon GraphQL Values directly and
 * in isolation of complete GraphQL documents.
 *
 * Consider providing the results to the utility func: valueFromAST().
 */
func parseValue(source: Source, noLocation: Bool = false) throws -> Value {
    let lexer = createLexer(source: source, noLocation: noLocation)
    try expect(lexer: lexer, kind: .sof)
    let value = try parseValueLiteral(lexer: lexer, isConst: false)
    try expect(lexer: lexer, kind: .eof)
    return value
}

/**
 * Given a string containing a GraphQL Type (ex. `[Int!]`), parse the AST for
 * that type.
 * Throws GraphQLError if a syntax error is encountered.
 *
 * This is useful within tools that operate upon GraphQL Types directly and
 * in isolation of complete GraphQL documents.
 *
 * Consider providing the results to the utility func: typeFromAST().
 */
func parseType(source: String, noLocation: Bool = false) throws -> Type {
    return try parseType(source: Source(body: source), noLocation: noLocation)
}

/**
 * Given a string containing a GraphQL Type (ex. `[Int!]`), parse the AST for
 * that type.
 * Throws GraphQLError if a syntax error is encountered.
 *
 * This is useful within tools that operate upon GraphQL Types directly and
 * in isolation of complete GraphQL documents.
 *
 * Consider providing the results to the utility func: typeFromAST().
 */
func parseType(source: Source, noLocation: Bool = false) throws -> Type {
    let lexer = createLexer(source: source, noLocation: noLocation)
    try expect(lexer: lexer, kind: .sof)
    let type = try parseTypeReference(lexer: lexer)
    try  expect(lexer: lexer,kind: .eof)
    return type
}

/**
 * Converts a name lex token into a name parse node.
 */
func parseName(lexer: Lexer) throws -> Name {
    let token = try expect(lexer: lexer, kind: .name)
    return Name(
        loc: loc(lexer: lexer, startToken: token),
        value: token.value!
    )
}

// Implements the parsing rules in the Document section.

/**
 * Document : Definition+
 */
func parseDocument(lexer: Lexer) throws -> Document {
    let start = lexer.token
    try expect(lexer: lexer, kind: .sof)
    var definitions: [Definition] = []

    repeat {
        definitions.append(try parseDefinition(lexer: lexer))
    } while try !skip(lexer: lexer, kind: .eof)

    return Document(
        loc: loc(lexer: lexer, startToken: start),
        definitions: definitions
    )
}

/**
 * Definition :
 *   - OperationDefinition
 *   - FragmentDefinition
 *   - TypeSystemDefinition
 */
func parseDefinition(lexer: Lexer) throws -> Definition {
    if peek(lexer: lexer, kind: .openingBrace) {
        return try parseOperationDefinition(lexer: lexer)
    }

    if peek(lexer: lexer, kind: .name) {
        switch lexer.token.value! {
        // Note: subscription is an experimental non-spec addition.
        case "query", "mutation", "subscription":
            return try parseOperationDefinition(lexer: lexer);
        case "fragment":
            return try parseFragmentDefinition(lexer: lexer)
        // Note: the Type System IDL is an experimental non-spec addition.
        case "schema", "scalar", "type", "interface", "union", "enum", "input", "extend", "directive": return try parseTypeSystemDefinition(lexer: lexer)
        default:
            break
        }
    }

    throw unexpected(lexer: lexer)
}


// Implements the parsing rules in the Operations section.

/**
 * OperationDefinition :
 *  - SelectionSet
 *  - OperationType Name? VariableDefinitions? Directives? SelectionSet
 */
func parseOperationDefinition(lexer: Lexer) throws -> OperationDefinition {
    let start = lexer.token

    if peek(lexer: lexer, kind: .openingBrace) {
        return OperationDefinition(
            loc: loc(lexer: lexer, startToken: start),
            operation: .query,
            name: nil,
            variableDefinitions: [], // nil
            directives: [],
            selectionSet: try parseSelectionSet(lexer: lexer)
        )
    }

    let operation = try parseOperationType(lexer: lexer)

    var name: Name? = nil

    if peek(lexer: lexer, kind: .name) {
        name = try parseName(lexer: lexer)
    }

    return OperationDefinition(
        loc: loc(lexer: lexer, startToken: start),
        operation: operation,
        name: name,
        variableDefinitions: try parseVariableDefinitions(lexer: lexer),
        directives: try parseDirectives(lexer: lexer),
        selectionSet: try parseSelectionSet(lexer: lexer)
    )
}

/**
 * OperationType : one of query mutation subscription
 */
func parseOperationType(lexer: Lexer) throws -> OperationType {
    let operationToken = try expect(lexer: lexer, kind: .name)

    switch operationToken.value! {
    case "query": return .query
    case "mutation": return .mutation
    // Note: subscription is an experimental non-spec addition.
    case "subscription": return .subscription
    default: throw unexpected(lexer: lexer, atToken: operationToken)
    }
}

/**
 * VariableDefinitions : ( VariableDefinition+ )
 */
func parseVariableDefinitions(lexer: Lexer) throws -> [VariableDefinition] {
    return peek(lexer: lexer, kind: .openingParenthesis) ?
        try many(
            lexer: lexer,
            openKind: .openingParenthesis,
            closeKind: .closingParenthesis,
            parse: parseVariableDefinition
        ) :
        []
}

/**
 * VariableDefinition : Variable : Type DefaultValue?
 */
func parseVariableDefinition(lexer: Lexer) throws -> VariableDefinition {
    let start = lexer.token
    return VariableDefinition(
        loc: loc(lexer: lexer, startToken: start),
        variable: try parseVariable(lexer: lexer),
        type: (try expect(lexer: lexer, kind: .colon), try parseTypeReference(lexer: lexer)).1,
        defaultValue: try skip(lexer: lexer, kind: .equals) ? parseValueLiteral(lexer: lexer, isConst:  true) : nil
    )
}

/**
 * Variable : $ Name
 */
func parseVariable(lexer: Lexer) throws -> Variable {
    let start = lexer.token;
    try expect(lexer: lexer, kind: .dollar)
    return Variable(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseName(lexer: lexer)
    )
}

/**
 * SelectionSet : { Selection+ }
 */
func parseSelectionSet(lexer: Lexer) throws -> SelectionSet {
    let start = lexer.token;
    return SelectionSet(
        loc: loc(lexer: lexer, startToken: start),
        selections: try many(
            lexer: lexer,
            openKind: .openingBrace,
            closeKind: .closingBrace,
            parse: parseSelection
        )
    )
}

/**
 * Selection :
 *   - Field
 *   - FragmentSpread
 *   - InlineFragment
 */
func parseSelection(lexer: Lexer) throws -> Selection {
    return peek(lexer: lexer, kind: .spread) ?
        try parseFragment(lexer: lexer) :
        try parseField(lexer: lexer)
}

/**
 * Field : Alias? Name Arguments? Directives? SelectionSet?
 *
 * Alias : Name :
 */
func parseField(lexer: Lexer) throws -> Field {
    let start = lexer.token;

    let nameOrAlias = try parseName(lexer: lexer)
    var alias: Name? = nil
    var name: Name

    if try skip(lexer: lexer, kind: .colon) {
        alias = nameOrAlias
        name = try parseName(lexer: lexer)
    } else {
        alias = nil
        name = nameOrAlias
    }

    return Field(
        loc: loc(lexer: lexer, startToken: start),
        alias: alias,
        name: name,
        arguments: try parseArguments(lexer: lexer),
        directives: try parseDirectives(lexer: lexer),
        selectionSet: peek(lexer: lexer, kind: .openingBrace) ? try parseSelectionSet(lexer: lexer) : nil
    )
}

/**
 * Arguments : ( Argument+ )
 */
func parseArguments(lexer: Lexer) throws -> [Argument] {
    return peek(lexer: lexer, kind: .openingParenthesis) ?
        try many(
            lexer: lexer,
            openKind: .openingParenthesis,
            closeKind: .closingParenthesis,
            parse: parseArgument
        ) : []
}

/**
 * Argument : Name : Value
 */
func parseArgument(lexer: Lexer) throws -> Argument {
    let start = lexer.token;
    return Argument(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseName(lexer: lexer),
        value: (try expect(lexer: lexer, kind: .colon), try parseValueLiteral(lexer: lexer, isConst:  false)).1
    )
}


// Implements the parsing rules in the Fragments section.

/**
 * Corresponds to both FragmentSpread and InlineFragment in the spec.
 *
 * FragmentSpread : ... FragmentName Directives?
 *
 * InlineFragment : ... TypeCondition? Directives? SelectionSet
 */
func parseFragment(lexer: Lexer) throws -> Fragment {
    let start = lexer.token
    try expect(lexer: lexer, kind: .spread)
    if peek(lexer: lexer, kind: .name) && lexer.token.value != "on" {
        return FragmentSpread(
            loc: loc(lexer: lexer, startToken: start),
            name: try parseFragmentName(lexer: lexer),
            directives: try parseDirectives(lexer: lexer)
        )
    }

    var typeCondition: NamedType? = nil

    if lexer.token.value == "on" {
        try lexer.advance()
        typeCondition = try parseNamedType(lexer: lexer)
    }
    return InlineFragment(
        loc: loc(lexer: lexer, startToken: start),
        typeCondition: typeCondition,
        directives: try parseDirectives(lexer: lexer),
        selectionSet: try parseSelectionSet(lexer: lexer)
    )
}

/**
 * FragmentDefinition :
 *   - fragment FragmentName on TypeCondition Directives? SelectionSet
 *
 * TypeCondition : NamedType
 */
func parseFragmentDefinition(lexer: Lexer) throws -> FragmentDefinition {
    let start = lexer.token
    try expectKeyword(lexer: lexer, value: "fragment")
    return FragmentDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseFragmentName(lexer: lexer),
        typeCondition: (try expectKeyword(lexer: lexer, value: "on"), try parseNamedType(lexer: lexer)).1,
        directives: try parseDirectives(lexer: lexer),
        selectionSet: try parseSelectionSet(lexer: lexer)
    )
}

/**
 * FragmentName : Name but not `on`
 */
func parseFragmentName(lexer: Lexer) throws -> Name {
    if lexer.token.value == "on" {
        throw unexpected(lexer: lexer)
    }
    return try parseName(lexer: lexer)
}


// Implements the parsing rules in the Values section.

/**
 * Value[Const] :
 *   - [~Const] Variable
 *   - IntValue
 *   - FloatValue
 *   - StringValue
 *   - BooleanValue
 *   - EnumValue
 *   - ListValue[?Const]
 *   - ObjectValue[?Const]
 *
 * BooleanValue : one of `true` `false`
 *
 * EnumValue : Name but not `true`, `false` or `null`
 */
func parseValueLiteral(lexer: Lexer, isConst: Bool) throws -> Value {
    let token = lexer.token
    switch token.kind {
    case .openingBracket:
        return try parseList(lexer: lexer, isConst: isConst)
    case .openingBrace:
        return try parseObject(lexer: lexer, isConst: isConst)
    case .int:
        try lexer.advance()
        return IntValue(
            loc: loc(lexer: lexer, startToken: token),
            value: token.value!
        )
    case .float:
        try lexer.advance()
        return FloatValue(
            loc: loc(lexer: lexer, startToken: token),
            value: token.value!
        )
    case .string:
        try lexer.advance();
        return StringValue(
            loc: loc(lexer: lexer, startToken: token),
            value: token.value!
        )
    case .name:
        if (token.value == "true" || token.value == "false") {
            try lexer.advance()
            return BooleanValue(
                loc: loc(lexer: lexer, startToken: token),
                value: token.value == "true"
            )
        } else if token.value != "null" {
            try lexer.advance()
            return EnumValue(
                loc: loc(lexer: lexer, startToken: token),
                value: token.value!
            )
        }
    case .dollar:
        if !isConst {
            return try parseVariable(lexer: lexer)
        }
    default:
        break
    }

    throw unexpected(lexer: lexer)
}

func parseConstValue(lexer: Lexer) throws -> Value {
    return try parseValueLiteral(lexer: lexer, isConst: true)
}

func parseValueValue(lexer: Lexer) throws -> Value {
    return try parseValueLiteral(lexer: lexer, isConst: false)
}

/**
 * ListValue[Const] :
 *   - [ ]
 *   - [ Value[?Const]+ ]
 */
func parseList(lexer: Lexer, isConst: Bool) throws -> ListValue {
    let start = lexer.token
    let item = isConst ? parseConstValue : parseValueValue
    return ListValue(
        loc: loc(lexer: lexer, startToken: start),
        values: try any(
            lexer: lexer,
            openKind: .openingBracket,
            closeKind: .closingBracket,
            parse: item
        )
    )
}

/**
 * ObjectValue[Const] :
 *   - { }
 *   - { ObjectField[?Const]+ }
 */
func parseObject(lexer: Lexer, isConst: Bool) throws -> ObjectValue {
    let start = lexer.token;
    try expect(lexer: lexer, kind: .openingBrace)
    var fields: [ObjectField] = []

    while try !skip(lexer: lexer, kind: .closingBrace) {
        fields.append(try parseObjectField(lexer: lexer, isConst: isConst))
    }

    return ObjectValue(
        loc: loc(lexer: lexer, startToken: start),
        fields: fields
    )
}

/**
 * ObjectField[Const] : Name : Value[?Const]
 */
func parseObjectField(lexer: Lexer, isConst: Bool) throws -> ObjectField {
    let start = lexer.token
    return ObjectField(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseName(lexer: lexer),
        value: (try expect(lexer: lexer, kind: .colon), try parseValueLiteral(lexer: lexer, isConst: isConst)).1
    )
}


// Implements the parsing rules in the Directives section.

/**
 * Directives : Directive+
 */
func parseDirectives(lexer: Lexer) throws -> [Directive] {
    var directives: [Directive] = []

    while peek(lexer: lexer, kind: .at) {
        directives.append(try parseDirective(lexer: lexer))
    }

    return directives
}

/**
 * Directive : @ Name Arguments?
 */
func parseDirective(lexer: Lexer) throws -> Directive {
    let start = lexer.token;
    try expect(lexer: lexer, kind: .at);
    return Directive(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseName(lexer: lexer),
        arguments: try parseArguments(lexer: lexer)
    )
}


// Implements the parsing rules in the Types section.

/**
 * Type :
 *   - NamedType
 *   - ListType
 *   - NonNullType
 */
func parseTypeReference(lexer: Lexer) throws -> Type {
    let start = lexer.token
    var type: Type
    
    if try skip(lexer: lexer, kind: .openingBracket) {
        type = try parseTypeReference(lexer: lexer)
        try expect(lexer: lexer, kind: .closingBracket)
        type = ListType(
            loc: loc(lexer: lexer, startToken: start),
            type: type
        )
    } else {
        type = try parseNamedType(lexer: lexer)
    }

    if try skip(lexer: lexer, kind: .bang) {
        return NonNullType(
            loc: loc(lexer: lexer, startToken: start),
            type: type as! NonNullableType
        )
    }

    return type
}

/**
 * NamedType : Name
 */
func parseNamedType(lexer: Lexer) throws -> NamedType {
    let start = lexer.token
    return NamedType(
        loc: loc(lexer: lexer, startToken: start),
        name: try parseName(lexer: lexer)
    )
}

// Implements the parsing rules in the Type Definition section.

/**
 * TypeSystemDefinition :
 *   - SchemaDefinition
 *   - TypeDefinition
 *   - TypeExtensionDefinition
 *   - DirectiveDefinition
 *
 * TypeDefinition :
 *   - ScalarTypeDefinition
 *   - ObjectTypeDefinition
 *   - InterfaceTypeDefinition
 *   - UnionTypeDefinition
 *   - EnumTypeDefinition
 *   - InputObjectTypeDefinition
 */
func parseTypeSystemDefinition(lexer: Lexer) throws -> TypeSystemDefinition {
    if peek(lexer: lexer, kind: .name) {
        switch lexer.token.value! {
        case "schema": return try parseSchemaDefinition(lexer: lexer);
        case "scalar": return try parseScalarTypeDefinition(lexer: lexer);
        case "type": return try parseObjectTypeDefinition(lexer: lexer);
        case "interface": return try parseInterfaceTypeDefinition(lexer: lexer);
        case "union": return try parseUnionTypeDefinition(lexer: lexer);
        case "enum": return try parseEnumTypeDefinition(lexer: lexer);
        case "input": return try parseInputObjectTypeDefinition(lexer: lexer);
        case "extend": return try parseTypeExtensionDefinition(lexer: lexer);
        case "directive": return try parseDirectiveDefinition(lexer: lexer);
        default: break
        }
    }

    throw unexpected(lexer: lexer)
}

/**
 * SchemaDefinition : schema Directives? { OperationTypeDefinition+ }
 *
 * OperationTypeDefinition : OperationType : NamedType
 */
func parseSchemaDefinition(lexer: Lexer) throws -> SchemaDefinition {
    let start = lexer.token
    try expectKeyword(lexer: lexer, value: "schema")
    let directives = try parseDirectives(lexer: lexer)
    let operationTypes = try many(
        lexer: lexer,
        openKind: .openingBrace,
        closeKind: .closingBrace,
        parse: parseOperationTypeDefinition
    )
    return SchemaDefinition(
        loc: loc(lexer: lexer, startToken: start),
        directives: directives,
        operationTypes: operationTypes
    )
}

func parseOperationTypeDefinition(lexer: Lexer) throws -> OperationTypeDefinition {
    let start = lexer.token;
    let operation = try parseOperationType(lexer: lexer)
    try expect(lexer: lexer, kind: .colon);
    let type = try parseNamedType(lexer: lexer);
    return OperationTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        operation: operation,
        type: type
    )
}

/**
 * ScalarTypeDefinition : scalar Name Directives?
 */
func parseScalarTypeDefinition(lexer: Lexer) throws -> ScalarTypeDefinition {
    let start = lexer.token
    try expectKeyword(lexer: lexer, value: "scalar")
    let name = try parseName(lexer: lexer)
    let directives = try parseDirectives(lexer: lexer)
    return ScalarTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives
    )
}

/**
 * ObjectTypeDefinition :
 *   - type Name ImplementsInterfaces? Directives? { FieldDefinition+ }
 */
func parseObjectTypeDefinition(lexer: Lexer) throws -> ObjectTypeDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "type")
    let name = try parseName(lexer: lexer);
    let interfaces = try parseImplementsInterfaces(lexer: lexer);
    let directives = try parseDirectives(lexer: lexer);
    let fields = try any(
        lexer: lexer,
        openKind: .openingBrace,
        closeKind: .closingBrace,
        parse: parseFieldDefinition
    )
    return ObjectTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        interfaces: interfaces,
        directives: directives,
        fields: fields
    )
}

/**
 * ImplementsInterfaces : implements NamedType+
 */
func parseImplementsInterfaces(lexer: Lexer) throws -> [NamedType] {
    var types: [NamedType] = []

    if lexer.token.value == "implements" {
        try lexer.advance()

        repeat {
            types.append(try parseNamedType(lexer: lexer))
        } while peek(lexer: lexer, kind: .name)
    }

    return types
}

/**
 * FieldDefinition : Name ArgumentsDefinition? : Type Directives?
 */
func parseFieldDefinition(lexer: Lexer) throws -> FieldDefinition {
    let start = lexer.token
    let name = try parseName(lexer: lexer)
    let args = try parseArgumentDefs(lexer: lexer)
    try expect(lexer: lexer, kind: .colon)
    let type = try parseTypeReference(lexer: lexer)
    let directives = try parseDirectives(lexer: lexer)
    return FieldDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        arguments: args,
        type: type,
        directives: directives
    )
}

/**
 * ArgumentsDefinition : ( InputValueDefinition+ )
 */
func parseArgumentDefs(lexer: Lexer) throws -> [InputValueDefinition] {
    if !peek(lexer: lexer, kind: .openingParenthesis) {
        return []
    }
    return try many(
        lexer: lexer,
        openKind: .openingParenthesis,
        closeKind: .closingParenthesis,
        parse: parseInputValueDef
    )
}

/**
 * InputValueDefinition : Name : Type DefaultValue? Directives?
 */
func parseInputValueDef(lexer: Lexer) throws -> InputValueDefinition {
    let start = lexer.token
    let name = try parseName(lexer: lexer)
    try expect(lexer: lexer, kind: .colon)
    let type = try parseTypeReference(lexer: lexer)
    var defaultValue: Value? = nil

    if try skip(lexer: lexer, kind: .equals) {
        defaultValue = try parseConstValue(lexer: lexer)
    }
    
    let directives = try parseDirectives(lexer: lexer)

    return InputValueDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        type: type,
        defaultValue: defaultValue,
        directives: directives
    )
}

/**
 * InterfaceTypeDefinition : interface Name Directives? { FieldDefinition+ }
 */
func parseInterfaceTypeDefinition(lexer: Lexer) throws -> InterfaceTypeDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "interface");
    let name = try parseName(lexer: lexer);
    let directives = try parseDirectives(lexer: lexer);
    let fields = try any(
        lexer: lexer,
        openKind: .openingBrace,
        closeKind: .closingBrace,
        parse: parseFieldDefinition
    )
    return InterfaceTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives,
        fields: fields
    )
}

/**
 * UnionTypeDefinition : union Name Directives? = UnionMembers
 */
func parseUnionTypeDefinition(lexer: Lexer) throws -> UnionTypeDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "union")
    let name = try parseName(lexer: lexer)
    let directives = try parseDirectives(lexer: lexer)
    try expect(lexer: lexer, kind: .equals)
    let types = try parseUnionMembers(lexer: lexer)
    return UnionTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives,
        types: types
    )
}

/**
 * UnionMembers :
 *   - NamedType
 *   - UnionMembers | NamedType
 */
func parseUnionMembers(lexer: Lexer) throws -> [NamedType] {
    var members: [NamedType] = []

    repeat {
        members.append(try parseNamedType(lexer: lexer))
    } while try skip(lexer: lexer, kind: .pipe)

    return members
}

/**
 * EnumTypeDefinition : enum Name Directives? { EnumValueDefinition+ }
 */
func parseEnumTypeDefinition(lexer: Lexer) throws -> EnumTypeDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "enum");
    let name = try parseName(lexer: lexer);
    let directives = try parseDirectives(lexer: lexer);
    let values = try many(
        lexer: lexer,
        openKind: .openingBrace,
        closeKind: .closingBrace,
        parse: parseEnumValueDefinition
    )
    return EnumTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives,
        values: values
    )
}

/**
 * EnumValueDefinition : EnumValue Directives?
 *
 * EnumValue : Name
 */
func parseEnumValueDefinition(lexer: Lexer) throws -> EnumValueDefinition {
    let start = lexer.token;
    let name = try parseName(lexer: lexer);
    let directives = try parseDirectives(lexer: lexer);
    return EnumValueDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives
    )
}

/**
 * InputObjectTypeDefinition : input Name Directives? { InputValueDefinition+ }
 */
func parseInputObjectTypeDefinition(lexer: Lexer) throws -> InputObjectTypeDefinition {
    let start = lexer.token
    try expectKeyword(lexer: lexer, value: "input")
    let name = try parseName(lexer: lexer)
    let directives = try parseDirectives(lexer: lexer)
    let fields = try any(
        lexer: lexer,
        openKind: .openingBrace,
        closeKind: .closingBrace,
        parse: parseInputValueDef
    )
    return InputObjectTypeDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        directives: directives,
        fields: fields
    )
}

/**
 * TypeExtensionDefinition : extend ObjectTypeDefinition
 */
func parseTypeExtensionDefinition(lexer: Lexer) throws -> TypeExtensionDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "extend");
    let definition = try parseObjectTypeDefinition(lexer: lexer);
    return TypeExtensionDefinition(
        loc: loc(lexer: lexer, startToken: start),
        definition: definition
    )
}

/**
 * DirectiveDefinition :
 *   - directive @ Name ArgumentsDefinition? on DirectiveLocations
 */
func parseDirectiveDefinition(lexer: Lexer) throws -> DirectiveDefinition {
    let start = lexer.token;
    try expectKeyword(lexer: lexer, value: "directive");
    try expect(lexer: lexer, kind: .at)
    let name = try parseName(lexer: lexer);
    let args = try parseArgumentDefs(lexer: lexer);
    try expectKeyword(lexer: lexer, value: "on");
    let locations = try parseDirectiveLocations(lexer: lexer);
    return DirectiveDefinition(
        loc: loc(lexer: lexer, startToken: start),
        name: name,
        arguments: args,
        locations: locations
    )
}

/**
 * DirectiveLocations :
 *   - Name
 *   - DirectiveLocations | Name
 */
func parseDirectiveLocations(lexer: Lexer) throws -> [Name] {
    var locations: [Name] = []

    repeat {
        locations.append(try parseName(lexer: lexer))
    } while try skip(lexer: lexer, kind: .pipe)

    return locations
}

// Core parsing utility funcs

/**
 * Returns a location object, used to identify the place in
 * the source that created a given parsed object.
 */
func loc(lexer: Lexer, startToken: Token) -> Location? {
    if !lexer.noLocation {
        return location(startToken: startToken, endToken: lexer.lastToken, source: lexer.source)
    }
    return nil
}

func location(startToken: Token, endToken: Token, source: Source) -> Location {
    return Location(
        start: startToken.start,
        end: endToken.end,
        startToken: startToken,
        endToken: endToken,
        source: source
    )
}

/**
 * Determines if the next token is of a given kind
 */
func peek(lexer: Lexer, kind: Token.Kind) -> Bool {
    return lexer.token.kind == kind
}

/**
 * If the next token is of the given kind, return true after advancing
 * the lexer. Otherwise, do not change the parser state and return false.
 */
func skip(lexer: Lexer, kind: Token.Kind) throws -> Bool {
    let match = lexer.token.kind == kind
    if match {
        try lexer.advance()
    }
    return match
}

/**
 * If the next token is of the given kind, return that token after advancing
 * the lexer. Otherwise, do not change the parser state and throw an error.
 */
@discardableResult
func expect(lexer: Lexer, kind: Token.Kind) throws -> Token {
    let token = lexer.token

    guard token.kind == kind else {
        throw syntaxError(
            source: lexer.source,
            position: token.start,
            description: "Expected \(kind), found \(getTokenDesc(token))"
        )
    }

    try lexer.advance()
    return token
}

/**
 * If the next token is a keyword with the given value, return that token after
 * advancing the lexer. Otherwise, do not change the parser state and return
 * false.
 */
@discardableResult
func expectKeyword(lexer: Lexer, value: String) throws -> Token {
    let token = lexer.token

    guard token.kind == .name && token.value == value else {
        throw syntaxError(
            source: lexer.source,
            position: token.start,
            description: "Expected \"\(value)\", found \(getTokenDesc(token))"
        )
    }

    try lexer.advance()
    return token
}

/**
 * Helper func for creating an error when an unexpected lexed token
 * is encountered.
 */
func unexpected(lexer: Lexer, atToken: Token? = nil) ->  Error { //GraphQLError {
    let token = atToken ?? lexer.token
    return syntaxError(
        source: lexer.source,
        position: token.start,
        description: "Unexpected \(getTokenDesc(token))"
    )
}

/**
 * Returns a possibly empty list of parse nodes, determined by
 * the parseFn. This list begins with a lex token of openKind
 * and ends with a lex token of closeKind. Advances the parser
 * to the next lex token after the closing token.
 */
func any<T>(
    lexer: Lexer,
    openKind: Token.Kind,
    closeKind: Token.Kind,
    parse: (Lexer) throws -> T
) throws -> [T] {
    try expect(lexer: lexer, kind: openKind)
    var nodes: [T] = []

    while try !skip(lexer: lexer, kind: closeKind) {
        nodes.append(try parse(lexer))
    }

    return nodes
}

/**
 * Returns a non-empty list of parse nodes, determined by
 * the parseFn. This list begins with a lex token of openKind
 * and ends with a lex token of closeKind. Advances the parser
 * to the next lex token after the closing token.
 */
func many<T>(
    lexer: Lexer,
    openKind: Token.Kind,
    closeKind: Token.Kind,
    parse: (Lexer) throws -> T
) throws -> [T] {
    try expect(lexer: lexer, kind: openKind)
    var nodes = [try parse(lexer)]
    while try !skip(lexer: lexer, kind: closeKind) {
        nodes.append(try parse(lexer))
    }
    return nodes
}
