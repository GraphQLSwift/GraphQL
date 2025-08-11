import OrderedCollections

/**
 * Produces a new schema given an existing schema and a document which may
 * contain GraphQL type extensions and definitions. The original schema will
 * remain unaltered.
 *
 * Because a schema represents a graph of references, a schema cannot be
 * extended without effectively making an entire copy. We do not know until it's
 * too late if subgraphs remain unchanged.
 *
 * This algorithm copies the provided schema, applying extensions while
 * producing the copy. The original schema remains unaltered.
 */
public func extendSchema(
    schema: GraphQLSchema,
    documentAST: Document,
    assumeValid: Bool = false,
    assumeValidSDL: Bool = false
) throws -> GraphQLSchema {
    if !assumeValid, !assumeValidSDL {
        try assertValidSDLExtension(documentAST: documentAST, schema: schema)
    }

    let schemaConfig = schema.toConfig()
    let extendedConfig = try extendSchemaImpl(schemaConfig, documentAST, assumeValid)

    return try ObjectIdentifier(schemaConfig) == ObjectIdentifier(extendedConfig)
        ? schema
        : GraphQLSchema(config: extendedConfig)
}

func extendSchemaImpl(
    _ schemaConfig: GraphQLSchemaNormalizedConfig,
    _ documentAST: Document,
    _ assumeValid: Bool = false
) throws -> GraphQLSchemaNormalizedConfig {
    // Collect the type definitions and extensions found in the document.
    var typeDefs = [TypeDefinition]()

    var scalarExtensions = [String: [ScalarExtensionDefinition]]()
    var objectExtensions = [String: [TypeExtensionDefinition]]()
    var interfaceExtensions = [String: [InterfaceExtensionDefinition]]()
    var unionExtensions = [String: [UnionExtensionDefinition]]()
    var enumExtensions = [String: [EnumExtensionDefinition]]()
    var inputObjectExtensions = [String: [InputObjectExtensionDefinition]]()

    // New directives and types are separate because a directives and types can
    // have the same name. For example, a type named "skip".
    var directiveDefs = [DirectiveDefinition]()

    var schemaDef: SchemaDefinition? = nil
    // Schema extensions are collected which may add additional operation types.
    var schemaExtensions = [SchemaExtensionDefinition]()

    var isSchemaChanged = false
    for def in documentAST.definitions {
        switch def.kind {
        case .schemaDefinition:
            schemaDef = (def as! SchemaDefinition)
        case .schemaExtensionDefinition:
            schemaExtensions.append(def as! SchemaExtensionDefinition)
        case .directiveDefinition:
            directiveDefs.append(def as! DirectiveDefinition)
        // Type Definitions
        case
            .scalarTypeDefinition,
            .objectTypeDefinition,
            .interfaceTypeDefinition,
            .unionTypeDefinition,
            .enumTypeDefinition,
            .inputObjectTypeDefinition
            :
            typeDefs.append(def as! TypeDefinition)
        // Type System Extensions
        case .scalarExtensionDefinition:
            let def = def as! ScalarExtensionDefinition
            var extensions = scalarExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            scalarExtensions[def.definition.name.value] = extensions
        case .typeExtensionDefinition:
            let def = def as! TypeExtensionDefinition
            var extensions = objectExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            objectExtensions[def.definition.name.value] = extensions
        case .interfaceExtensionDefinition:
            let def = def as! InterfaceExtensionDefinition
            var extensions = interfaceExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            interfaceExtensions[def.definition.name.value] = extensions
        case .unionExtensionDefinition:
            let def = def as! UnionExtensionDefinition
            var extensions = unionExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            unionExtensions[def.definition.name.value] = extensions
        case .enumExtensionDefinition:
            let def = def as! EnumExtensionDefinition
            var extensions = enumExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            enumExtensions[def.definition.name.value] = extensions
        case .inputObjectExtensionDefinition:
            let def = def as! InputObjectExtensionDefinition
            var extensions = inputObjectExtensions[def.definition.name.value] ?? []
            extensions.append(def)
            inputObjectExtensions[def.definition.name.value] = extensions
        default:
            continue
        }
        isSchemaChanged = true
    }

    // If this document contains no new types, extensions, or directives then
    // return the same unmodified GraphQLSchema instance.
    if !isSchemaChanged {
        return schemaConfig
    }

    var typeMap = OrderedDictionary<String, GraphQLNamedType>()
    for type in schemaConfig.types {
        typeMap[type.name] = try extendNamedType(type)
    }

    for typeNode in typeDefs {
        let name = typeNode.name.value
        typeMap[name] = try stdTypeMap[name] ?? buildType(astNode: typeNode)
    }

    // Get the extended root operation types.
    var query = schemaConfig.query.map { replaceNamedType($0) }
    var mutation = schemaConfig.mutation.map { replaceNamedType($0) }
    var subscription = schemaConfig.subscription.map { replaceNamedType($0) }
    // Then, incorporate schema definition and all schema extensions.
    if let schemaDef = schemaDef {
        let schemaOperations = try getOperationTypes(nodes: [schemaDef])
        query = schemaOperations.query ?? query
        mutation = schemaOperations.mutation ?? mutation
        subscription = schemaOperations.subscription ?? subscription
    }
    let extensionOperations = try getOperationTypes(nodes: schemaExtensions)
    query = extensionOperations.query ?? query
    mutation = extensionOperations.mutation ?? mutation
    subscription = extensionOperations.subscription ?? subscription

    var extensionASTNodes = schemaConfig.extensionASTNodes
    extensionASTNodes.append(contentsOf: schemaExtensions)

    var directives = [GraphQLDirective]()
    for directive in schemaConfig.directives {
        try directives.append(replaceDirective(directive))
    }
    for directive in directiveDefs {
        try directives.append(buildDirective(node: directive))
    }
    // Then, incorporate schema definition and all schema extensions.
    return GraphQLSchemaNormalizedConfig(
        description: schemaDef?.description?.value ?? schemaConfig.description,
        query: query,
        mutation: mutation,
        subscription: subscription,
        types: Array(typeMap.values),
        directives: directives,
        extensions: schemaConfig.extensions,
        astNode: schemaDef ?? schemaConfig.astNode,
        extensionASTNodes: extensionASTNodes,
        assumeValid: assumeValid
    )

    // Below are functions used for producing this schema that have closed over
    // this scope and have access to the schema, cache, and newly defined types.

    func replaceType<T: GraphQLType>(_ type: T) -> T {
        if let type = type as? GraphQLList {
            return GraphQLList(replaceType(type.ofType)) as! T
        }
        if let type = type as? GraphQLNonNull {
            return GraphQLNonNull(replaceType(type.ofType)) as! T
        }
        if let type = type as? GraphQLNamedType {
            return replaceNamedType(type) as! T
        }
        return type
    }

    func replaceNamedType<T: GraphQLNamedType>(_ type: T) -> T {
        // Note: While this could make early assertions to get the correctly
        // typed values, that would throw immediately while type system
        // validation with validateSchema() will produce more actionable results.
        return typeMap[type.name] as! T
    }

    func replaceDirective(_ directive: GraphQLDirective) throws -> GraphQLDirective {
        if isSpecifiedDirective(directive) {
            // Builtin directives are not extended.
            return directive
        }

        return try GraphQLDirective(
            name: directive.name,
            description: directive.description,
            locations: directive.locations,
            args: directive.argConfigMap().mapValues { arg in extendArg(arg) },
            isRepeatable: directive.isRepeatable,
            astNode: directive.astNode
        )
    }

    func extendNamedType(_ type: GraphQLNamedType) throws -> GraphQLNamedType {
        if isIntrospectionType(type: type) || isSpecifiedScalarType(type) {
            // Builtin types are not extended.
            return type
        }
        if let type = type as? GraphQLScalarType {
            return try extendScalarType(type)
        }
        if let type = type as? GraphQLObjectType {
            return try extendObjectType(type)
        }
        if let type = type as? GraphQLInterfaceType {
            return try extendInterfaceType(type)
        }
        if let type = type as? GraphQLUnionType {
            return try extendUnionType(type)
        }
        if let type = type as? GraphQLEnumType {
            return try extendEnumType(type)
        }
        if let type = type as? GraphQLInputObjectType {
            return try extendInputObjectType(type)
        }

        // Not reachable, all possible type definition nodes have been considered.
        throw GraphQLError(message: "Unexpected type: \(type.name)")
    }

    func extendInputObjectType(
        _ type: GraphQLInputObjectType
    ) throws -> GraphQLInputObjectType {
        let extensions = inputObjectExtensions[type.name] ?? []
        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)

        return try GraphQLInputObjectType(
            name: type.name,
            description: type.description,
            fields: {
                let fields = try type.getFields().mapValues { field in
                    InputObjectField(
                        type: replaceType(field.type),
                        defaultValue: field.defaultValue,
                        description: field.description,
                        deprecationReason: field.deprecationReason,
                        astNode: field.astNode
                    )
                }.merging(buildInputFieldMap(nodes: extensions)) { $1 }
                return fields
            },
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendEnumType(_ type: GraphQLEnumType) throws -> GraphQLEnumType {
        let extensions = enumExtensions[type.name] ?? []
        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)

        var values = GraphQLEnumValueMap()
        for value in type.values {
            values[value.name] = GraphQLEnumValue(
                value: value.value,
                description: value.description,
                deprecationReason: value.deprecationReason,
                astNode: value.astNode
            )
        }
        for (name, value) in try buildEnumValueMap(nodes: extensions) {
            values[name] = value
        }

        return try GraphQLEnumType(
            name: type.name,
            description: type.description,
            values: values,
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendScalarType(_ type: GraphQLScalarType) throws -> GraphQLScalarType {
        let extensions = scalarExtensions[type.name] ?? []
        var specifiedByURL = type.specifiedByURL
        for extensionNode in extensions {
            specifiedByURL = try getSpecifiedByURL(node: extensionNode) ?? specifiedByURL
        }

        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)
        return try GraphQLScalarType(
            name: type.name,
            description: type.description,
            specifiedByURL: specifiedByURL,
            serialize: type.serialize,
            parseValue: type.parseValue,
            parseLiteral: type.parseLiteral,
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendObjectType(_ type: GraphQLObjectType) throws -> GraphQLObjectType {
        let extensions = objectExtensions[type.name] ?? []
        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)

        return try GraphQLObjectType(
            name: type.name,
            description: type.description,
            fields: {
                try type.getFields().mapValues { field in
                    extendField(field.toField())
                }.merging(buildFieldMap(nodes: extensions)) { $1 }
            },
            interfaces: {
                var interfaces = try type.getInterfaces().map { interface in
                    replaceNamedType(interface)
                }
                try interfaces.append(contentsOf: buildInterfaces(nodes: extensions))
                return interfaces
            },
            isTypeOf: type.isTypeOf,
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendInterfaceType(_ type: GraphQLInterfaceType) throws -> GraphQLInterfaceType {
        let extensions = interfaceExtensions[type.name] ?? []
        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)

        return try GraphQLInterfaceType(
            name: type.name,
            description: type.description,
            fields: {
                try type.getFields().mapValues { field in
                    extendField(field.toField())
                }.merging(buildFieldMap(nodes: extensions)) { $1 }
            },
            interfaces: {
                var interfaces = try type.getInterfaces().map { interface in
                    replaceNamedType(interface)
                }
                try interfaces.append(contentsOf: buildInterfaces(nodes: extensions))
                return interfaces
            },
            resolveType: type.resolveType,
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendUnionType(_ type: GraphQLUnionType) throws -> GraphQLUnionType {
        let extensions = unionExtensions[type.name] ?? []
        var extensionASTNodes = type.extensionASTNodes
        extensionASTNodes.append(contentsOf: extensions)

        return try GraphQLUnionType(
            name: type.name,
            description: type.description,
            resolveType: type.resolveType,
            types: {
                var types = try type.getTypes().map { type in
                    replaceNamedType(type)
                }
                try types.append(contentsOf: buildUnionTypes(nodes: extensions))
                return types
            },
            astNode: type.astNode,
            extensionASTNodes: extensionASTNodes
        )
    }

    func extendField(_ field: GraphQLField) -> GraphQLField {
        let args = field.args.merging(field.args.mapValues { extendArg($0) }) { $1 }
        return GraphQLField(
            type: replaceType(field.type),
            description: field.description,
            deprecationReason: field.deprecationReason,
            args: args,
            resolve: field.resolve,
            subscribe: field.subscribe,
            astNode: field.astNode
        )
    }

    func extendArg(_ arg: GraphQLArgument) -> GraphQLArgument {
        return GraphQLArgument(
            type: replaceType(arg.type),
            description: arg.description,
            defaultValue: arg.defaultValue,
            deprecationReason: arg.deprecationReason,
            astNode: arg.astNode
        )
    }

    struct OperationTypes: Sendable {
        let query: GraphQLObjectType?
        let mutation: GraphQLObjectType?
        let subscription: GraphQLObjectType?
    }

    func getOperationTypes(
        nodes: [SchemaDefinition]
    ) throws -> OperationTypes {
        var query: GraphQLObjectType? = nil
        var mutation: GraphQLObjectType? = nil
        var subscription: GraphQLObjectType? = nil
        for node in nodes {
            let operationTypesNodes = node.operationTypes

            for operationType in operationTypesNodes {
                let namedType = try getNamedType(operationType.type)

                switch operationType.operation {
                case .query:
                    query = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                case .mutation:
                    mutation = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                case .subscription:
                    subscription = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                }
            }
        }

        return OperationTypes(query: query, mutation: mutation, subscription: subscription)
    }

    func getOperationTypes(
        nodes: [SchemaExtensionDefinition]
    ) throws -> OperationTypes {
        var query: GraphQLObjectType? = nil
        var mutation: GraphQLObjectType? = nil
        var subscription: GraphQLObjectType? = nil
        for node in nodes {
            let operationTypesNodes = node.definition.operationTypes

            for operationType in operationTypesNodes {
                let namedType = try getNamedType(operationType.type)
                switch operationType.operation {
                case .query:
                    query = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                case .mutation:
                    mutation = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                case .subscription:
                    subscription = try checkOperationType(
                        operationType: operationType.operation,
                        type: namedType
                    )
                }
            }
        }

        return OperationTypes(query: query, mutation: mutation, subscription: subscription)
    }

    func getNamedType(_ node: NamedType) throws -> GraphQLNamedType {
        let name = node.name.value
        let type = stdTypeMap[name] ?? typeMap[name]

        guard let type = type else {
            throw GraphQLError(message: "Unknown type: \"\(name)\".")
        }
        return type
    }

    func getWrappedType(_ node: Type) throws -> GraphQLType {
        if let node = node as? ListType {
            return try GraphQLList(getWrappedType(node.type))
        }
        if let node = node as? NonNullType {
            return try GraphQLNonNull(getWrappedType(node.type))
        }
        if let node = node as? NamedType {
            return try getNamedType(node)
        }
        throw GraphQLError(
            message: "No type wrapped"
        )
    }

    func buildDirective(node: DirectiveDefinition) throws -> GraphQLDirective {
        return try GraphQLDirective(
            name: node.name.value,
            description: node.description?.value,
            locations: node.locations.compactMap { DirectiveLocation(rawValue: $0.value) },
            args: buildArgumentMap(node.arguments, methodFormat: "@\(node.name.printed)"),
            isRepeatable: node.repeatable,
            astNode: node
        )
    }

    func buildFieldMap(
        nodes: [InterfaceTypeDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.fields {
                fieldConfigMap[field.name.value] = try .init(
                    type: checkedFieldType(field, typeName: node.name),
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(
                        field.arguments,
                        methodFormat: "\(node.name.printed).\(field.name.printed)"
                    ),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [InterfaceExtensionDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                fieldConfigMap[field.name.value] = try .init(
                    type: checkedFieldType(field, typeName: node.name),
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(
                        field.arguments,
                        methodFormat: "\(node.name.printed).\(field.name.printed)"
                    ),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [ObjectTypeDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.fields {
                fieldConfigMap[field.name.value] = try .init(
                    type: checkedFieldType(field, typeName: node.name),
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(
                        field.arguments,
                        methodFormat: "\(node.name.printed).\(field.name.printed)"
                    ),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func buildFieldMap(
        nodes: [TypeExtensionDefinition]
    ) throws -> GraphQLFieldMap {
        var fieldConfigMap = GraphQLFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                fieldConfigMap[field.name.value] = try .init(
                    type: checkedFieldType(field, typeName: node.name),
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    args: buildArgumentMap(
                        field.arguments,
                        methodFormat: "\(node.name.printed).\(field.name.printed)"
                    ),
                    astNode: field
                )
            }
        }
        return fieldConfigMap
    }

    func checkedFieldType(_ field: FieldDefinition, typeName: Name) throws -> GraphQLOutputType {
        let wrappedType = try getWrappedType(field.type)
        var checkType = wrappedType
        // Must unwind List & NonNull types to work around not having conditional conformances
        if let listType = wrappedType as? GraphQLList {
            checkType = listType.ofType
        } else if let nonNullType = wrappedType as? GraphQLNonNull {
            checkType = nonNullType.ofType
        }
        guard let type = wrappedType as? GraphQLOutputType, checkType is GraphQLOutputType else {
            throw GraphQLError(
                message: "The type of \(typeName.printed).\(field.name.printed) must be Output Type but got: \(field.type)."
            )
        }
        return type
    }

    func buildArgumentMap(
        _ args: [InputValueDefinition]?,
        methodFormat: String
    ) throws -> GraphQLArgumentConfigMap {
        let argsNodes = args ?? []

        var argConfigMap = GraphQLArgumentConfigMap()
        for arg in argsNodes {
            guard let type = try getWrappedType(arg.type) as? GraphQLInputType else {
                throw GraphQLError(
                    message: "The type of \(methodFormat)(\(arg.name):) must be Input Type but got: \(print(ast: arg.type))."
                )
            }

            argConfigMap[arg.name.value] = try GraphQLArgument(
                type: type,
                description: arg.description?.value,
                defaultValue: arg.defaultValue.map { try valueFromAST(valueAST: $0, type: type) },
                deprecationReason: getDeprecationReason(arg),
                astNode: arg
            )
        }
        return argConfigMap
    }

    func buildInputFieldMap(
        nodes: [InputObjectTypeDefinition]
    ) throws -> InputObjectFieldMap {
        var inputFieldMap = InputObjectFieldMap()
        for node in nodes {
            for field in node.fields {
                let type = try getWrappedType(field.type)
                guard let type = type as? GraphQLInputType else {
                    throw GraphQLError(
                        message: "The type of \(node.name.printed).\(field.name.printed) must be Input Type but got: \(type)."
                    )
                }

                inputFieldMap[field.name.value] = try .init(
                    type: type,
                    defaultValue: field.defaultValue
                        .map { try valueFromAST(valueAST: $0, type: type) },
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    astNode: field
                )
            }
        }
        return inputFieldMap
    }

    func buildInputFieldMap(
        nodes: [InputObjectExtensionDefinition]
    ) throws -> InputObjectFieldMap {
        var inputFieldMap = InputObjectFieldMap()
        for node in nodes {
            for field in node.definition.fields {
                // Note: While this could make assertions to get the correctly typed
                // value, that would throw immediately while type system validation
                // with validateSchema() will produce more actionable results.
                let type = try getWrappedType(field.type)
                guard let type = type as? GraphQLInputType else {
                    throw GraphQLError(
                        message: "The type of \(node.name.printed).\(field.name.printed) must be Input Type but got: \(type)."
                    )
                }

                inputFieldMap[field.name.value] = try .init(
                    type: type,
                    defaultValue: field.defaultValue
                        .map { try valueFromAST(valueAST: $0, type: type) },
                    description: field.description?.value,
                    deprecationReason: getDeprecationReason(field),
                    astNode: field
                )
            }
        }
        return inputFieldMap
    }

    func buildEnumValueMap(
        nodes: [EnumTypeDefinition] // | EnumTypeExtension],
    ) throws -> GraphQLEnumValueMap {
        var enumValueMap = GraphQLEnumValueMap()
        for node in nodes {
            for value in node.values {
                enumValueMap[value.name.value] = try GraphQLEnumValue(
                    value: .string(value.name.value),
                    description: value.description?.value,
                    deprecationReason: getDeprecationReason(value),
                    astNode: value
                )
            }
        }
        return enumValueMap
    }

    func buildEnumValueMap(
        nodes: [EnumExtensionDefinition]
    ) throws -> GraphQLEnumValueMap {
        var enumValueMap = GraphQLEnumValueMap()
        for node in nodes {
            for value in node.definition.values {
                enumValueMap[value.name.value] = try GraphQLEnumValue(
                    value: .string(value.name.value),
                    description: value.description?.value,
                    deprecationReason: getDeprecationReason(value),
                    astNode: value
                )
            }
        }
        return enumValueMap
    }

    func buildInterfaces(
        nodes: [ObjectTypeDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try checkedInterfaceTypes(node)
        }
    }

    func buildInterfaces(
        nodes: [TypeExtensionDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try checkedInterfaceTypes(node.definition)
        }
    }

    func buildInterfaces(
        nodes: [InterfaceTypeDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try checkedInterfaceTypes(node)
        }
    }

    func buildInterfaces(
        nodes: [InterfaceExtensionDefinition]
    ) throws -> [GraphQLInterfaceType] {
        return try nodes.flatMap { node in
            try checkedInterfaceTypes(node.definition)
        }
    }

    func checkedInterfaceTypes(_ type: ObjectTypeDefinition) throws -> [GraphQLInterfaceType] {
        var interfaces = [GraphQLInterfaceType]()
        for interface in type.interfaces {
            let namedType = try getNamedType(interface)
            guard let checkedInterface = namedType as? GraphQLInterfaceType else {
                throw GraphQLError(
                    message: "Type \(type.name.printed) must only implement Interface types, it cannot implement \(namedType.name)."
                )
            }
            interfaces.append(checkedInterface)
        }
        return interfaces
    }

    func checkedInterfaceTypes(_ type: InterfaceTypeDefinition) throws -> [GraphQLInterfaceType] {
        var interfaces = [GraphQLInterfaceType]()
        for interface in type.interfaces {
            let namedType = try getNamedType(interface)
            guard let checkedInterface = namedType as? GraphQLInterfaceType else {
                throw GraphQLError(
                    message: "Type \(type.name.printed) must only implement Interface types, it cannot implement \(namedType.name)."
                )
            }
            interfaces.append(checkedInterface)
        }
        return interfaces
    }

    func buildUnionTypes(
        nodes: [UnionTypeDefinition]
    ) throws -> [GraphQLObjectType] {
        return try nodes.flatMap { node in
            try checkedUnionTypes(node)
        }
    }

    func buildUnionTypes(
        nodes: [UnionExtensionDefinition]
    ) throws -> [GraphQLObjectType] {
        return try nodes.flatMap { node in
            try checkedUnionTypes(node.definition)
        }
    }

    func checkedUnionTypes(_ union: UnionTypeDefinition) throws -> [GraphQLObjectType] {
        var types = [GraphQLObjectType]()
        for type in union.types {
            let namedType = try getNamedType(type)
            guard let checkedType = namedType as? GraphQLObjectType else {
                throw GraphQLError(
                    message: "Union type \(type.name.printed) can only include Object types, it cannot include \(namedType.name)."
                )
            }
            types.append(checkedType)
        }
        return types
    }

    func buildType(astNode: TypeDefinition) throws -> GraphQLNamedType {
        let name = astNode.name.value

        switch astNode.kind {
        case Kind.objectTypeDefinition:
            let node = astNode as! ObjectTypeDefinition
            let extensionASTNodes = objectExtensions[name] ?? []

            return try GraphQLObjectType(
                name: name,
                description: node.description?.value,
                fields: {
                    var fields = try buildFieldMap(nodes: [node])
                    for (name, value) in try buildFieldMap(nodes: extensionASTNodes) {
                        fields[name] = value
                    }
                    return fields
                },
                interfaces: {
                    var interfaces = try buildInterfaces(nodes: [node])
                    try interfaces.append(contentsOf: buildInterfaces(nodes: extensionASTNodes))
                    return interfaces
                },
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.interfaceTypeDefinition:
            let node = astNode as! InterfaceTypeDefinition
            let extensionASTNodes = interfaceExtensions[name] ?? []

            return try GraphQLInterfaceType(
                name: name,
                description: node.description?.value,
                fields: {
                    var fields = try buildFieldMap(nodes: [node])
                    for (name, value) in try buildFieldMap(nodes: extensionASTNodes) {
                        fields[name] = value
                    }
                    return fields
                },
                interfaces: {
                    var interfaces = try buildInterfaces(nodes: [node])
                    try interfaces.append(contentsOf: buildInterfaces(nodes: extensionASTNodes))
                    return interfaces
                },
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.enumTypeDefinition:
            let node = astNode as! EnumTypeDefinition
            let extensionASTNodes = enumExtensions[name] ?? []

            var enumValues = try buildEnumValueMap(nodes: [node])
            for (name, value) in try buildEnumValueMap(nodes: extensionASTNodes) {
                enumValues[name] = value
            }

            return try GraphQLEnumType(
                name: name,
                description: node.description?.value,
                values: enumValues,
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.unionTypeDefinition:
            let node = astNode as! UnionTypeDefinition
            let extensionASTNodes = unionExtensions[name] ?? []

            return try GraphQLUnionType(
                name: name,
                description: node.description?.value,
                types: {
                    var unionTypes = try buildUnionTypes(nodes: [node])
                    try unionTypes.append(contentsOf: buildUnionTypes(nodes: extensionASTNodes))
                    return unionTypes
                },
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.scalarTypeDefinition:
            let node = astNode as! ScalarTypeDefinition
            let extensionASTNodes = scalarExtensions[name] ?? []

            return try GraphQLScalarType(
                name: name,
                description: node.description?.value,
                specifiedByURL: getSpecifiedByURL(node: node),
                astNode: node,
                extensionASTNodes: extensionASTNodes
            )
        case Kind.inputObjectTypeDefinition:
            let node = astNode as! InputObjectTypeDefinition
            let extensionASTNodes = inputObjectExtensions[name] ?? []

            return try GraphQLInputObjectType(
                name: name,
                description: node.description?.value,
                fields: {
                    var fields = try buildInputFieldMap(nodes: [node])
                    for (name, value) in try buildInputFieldMap(nodes: extensionASTNodes) {
                        fields[name] = value
                    }
                    return fields
                },
                astNode: node,
                extensionASTNodes: extensionASTNodes,
                isOneOf: isOneOf(node: node)
            )
        default:
            throw GraphQLError(message: "Unsupported kind: \(astNode.kind)")
        }
    }
}

func checkOperationType(
    operationType: OperationType,
    type: GraphQLNamedType
) throws -> GraphQLObjectType {
    let operationTypeStr = operationType.rawValue.capitalized
    let rootTypeStr = type.name
    guard let objectType = type as? GraphQLObjectType else {
        let message = operationType == .query
            ? "\(operationTypeStr) root type must be Object type, it cannot be \(rootTypeStr)."
            : "\(operationTypeStr) root type must be Object type, it cannot be \(rootTypeStr)."
        throw GraphQLError(message: message)
    }
    return objectType
}

let stdTypeMap = {
    var types = [GraphQLNamedType]()
    types.append(contentsOf: specifiedScalarTypes)
    types.append(contentsOf: introspectionTypes)

    var typeMap = [String: GraphQLNamedType]()
    for type in types {
        typeMap[type.name] = type
    }
    return typeMap
}()

/**
 * Given a field or enum value node, returns the string value for the
 * deprecation reason.
 */

func getDeprecationReason(
    _ node: EnumValueDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

func getDeprecationReason(
    _ node: FieldDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

func getDeprecationReason(
    _ node: InputValueDefinition
) throws -> String? {
    let deprecated = try getDirectiveValues(
        directiveDef: GraphQLDeprecatedDirective,
        directives: node.directives
    )
    return deprecated?.dictionary?["reason"]?.string
}

/**
 * Given a scalar node, returns the string value for the specifiedByURL.
 */
func getSpecifiedByURL(
    node: ScalarTypeDefinition
) throws -> String? {
    let specifiedBy = try getDirectiveValues(
        directiveDef: GraphQLSpecifiedByDirective,
        directives: node.directives
    )
    return specifiedBy?.dictionary?["url"]?.string
}

func getSpecifiedByURL(
    node: ScalarExtensionDefinition
) throws -> String? {
    let specifiedBy = try getDirectiveValues(
        directiveDef: GraphQLSpecifiedByDirective,
        directives: node.directives
    )
    return specifiedBy?.dictionary?["url"]?.string
}

/**
 * Given an input object node, returns if the node should be OneOf.
 */
func isOneOf(node: InputObjectTypeDefinition) throws -> Bool {
    let isOneOf = try getDirectiveValues(
        directiveDef: GraphQLOneOfDirective,
        directives: node.directives
    )
    return isOneOf != nil
}
