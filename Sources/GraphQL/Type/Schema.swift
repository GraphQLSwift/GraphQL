import OrderedCollections

/**
 * Schema Definition
 *
 * A Schema is created by supplying the root types of each type of operation,
 * query and mutation (optional). A schema definition is then supplied to the
 * validator and executor.
 *
 * Example:
 *
 *     let MyAppSchema = GraphQLSchema(
 *         query: MyAppQueryRootType,
 *         mutation: MyAppMutationRootType,
 *     )
 *
 * Note: If an array of `directives` are provided to GraphQLSchema, that will be
 * the exact list of directives represented and allowed. If `directives` is not
 * provided then a default set of the specified directives (e.g. @include and
 * @skip) will be used. If you wish to provide *additional* directives to these
 * specified directives, you must explicitly declare them. Example:
 *
 *     let MyAppSchema = GraphQLSchema(
 *         ...
 *         directives: specifiedDirectives + [myCustomDirective],
 *         ...
 *     )
 *
 */
public final class GraphQLSchema {
    let description: String?
    let extensions: [GraphQLSchemaExtensions]
    let astNode: SchemaDefinition?
    let extensionASTNodes: [SchemaExtensionDefinition]

    // Used as a cache for validateSchema().
    var validationErrors: [GraphQLError]?

    public let queryType: GraphQLObjectType?
    public let mutationType: GraphQLObjectType?
    public let subscriptionType: GraphQLObjectType?
    public let directives: [GraphQLDirective]
    public let typeMap: TypeMap
    public internal(set) var implementations: [String: InterfaceImplementations]
    private var subTypeMap: [String: [String: Bool]] = [:]

    public init(
        description: String? = nil,
        query: GraphQLObjectType? = nil,
        mutation: GraphQLObjectType? = nil,
        subscription: GraphQLObjectType? = nil,
        types: [GraphQLNamedType] = [],
        directives: [GraphQLDirective] = [],
        extensions: [GraphQLSchemaExtensions] = [],
        astNode: SchemaDefinition? = nil,
        extensionASTNodes: [SchemaExtensionDefinition] = [],
        assumeValid: Bool = false
    ) throws {
        validationErrors = assumeValid ? [] : nil

        self.description = description
        self.extensions = extensions
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes

        queryType = query
        mutationType = mutation
        subscriptionType = subscription

        // Provide specified directives (e.g. @include and @skip) by default.
        self.directives = directives.isEmpty ? specifiedDirectives : directives

        // To preserve order of user-provided types, we add first to add them to
        // the set of "collected" types, so `collectReferencedTypes` ignore them.
        var allReferencedTypes = TypeMap()
        for type in types {
            allReferencedTypes[type.name] = type
        }
        if !types.isEmpty {
            for type in types {
                // When we ready to process this type, we remove it from "collected" types
                // and then add it together with all dependent types in the correct position.
                allReferencedTypes[type.name] = nil
                allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: type)
            }
        }

        if let query = queryType {
            allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: query)
        }

        if let mutation = mutationType {
            allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: mutation)
        }

        if let subscription = subscriptionType {
            allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: subscription)
        }

        for directive in self.directives {
            for arg in directive.args {
                allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: arg.type)
            }
        }

        allReferencedTypes = try typeMapReducer(typeMap: allReferencedTypes, type: __Schema)
        try replaceTypeReferences(typeMap: allReferencedTypes)

        // Storing the resulting map for reference by the schema.
        var typeMap = TypeMap()

        // Keep track of all implementations by interface name.
        implementations = try collectImplementations(types: Array(typeMap.values))

        for namedType in allReferencedTypes.values {
            let typeName = namedType.name
            if typeMap[typeName] != nil {
                throw GraphQLError(
                    message:
                    "Schema must contain uniquely named types but contains multiple types named \"\(typeName)\"."
                )
            }
            typeMap[typeName] = namedType

            if let namedType = namedType as? GraphQLInterfaceType {
                // Store implementations by interface.
                for iface in try namedType.getInterfaces() {
                    let implementations = self.implementations[iface.name] ?? .init(
                        objects: [],
                        interfaces: []
                    )

                    var interfaces = implementations.interfaces
                    interfaces.append(namedType)
                    self.implementations[iface.name] = .init(
                        objects: implementations.objects,
                        interfaces: interfaces
                    )
                }
            } else if let namedType = namedType as? GraphQLObjectType {
                // Store implementations by objects.
                for iface in try namedType.getInterfaces() {
                    let implementations = self.implementations[iface.name] ?? .init(
                        objects: [],
                        interfaces: []
                    )

                    var objects = implementations.objects
                    objects.append(namedType)
                    self.implementations[iface.name] = .init(
                        objects: objects,
                        interfaces: implementations.interfaces
                    )
                }
            }
        }

        self.typeMap = typeMap
    }

    convenience init(config: GraphQLSchemaNormalizedConfig) throws {
        try self.init(
            description: config.description,
            query: config.query,
            mutation: config.mutation,
            subscription: config.subscription,
            types: config.types,
            directives: config.directives,
            extensions: config.extensions,
            astNode: config.astNode,
            extensionASTNodes: config.extensionASTNodes,
            assumeValid: config.assumeValid
        )
    }

    public func getType(name: String) -> GraphQLNamedType? {
        return typeMap[name]
    }

    public func getPossibleTypes(abstractType: GraphQLAbstractType) -> [GraphQLObjectType] {
        if let unionType = abstractType as? GraphQLUnionType {
            return (try? unionType.getTypes()) ?? []
        }

        if let interfaceType = abstractType as? GraphQLInterfaceType {
            return getImplementations(interfaceType: interfaceType).objects
        }

        fatalError(
            "Should be impossible. Only UnionType and InterfaceType should conform to AbstractType"
        )
    }

    public func getImplementations(
        interfaceType: GraphQLInterfaceType
    ) -> InterfaceImplementations {
        guard let matchingImplementations = implementations[interfaceType.name] else {
            // If we ask for an interface that hasn't been defined, just return no types.
            return InterfaceImplementations()
        }
        return matchingImplementations
    }

    // @deprecated: use isSubType instead - will be removed in the future.
    public func isPossibleType(
        abstractType: GraphQLAbstractType,
        possibleType: GraphQLObjectType
    ) throws -> Bool {
        isSubType(abstractType: abstractType, maybeSubType: possibleType)
    }

    public func isSubType(
        abstractType: GraphQLAbstractType,
        maybeSubType: GraphQLNamedType
    ) -> Bool {
        var map = subTypeMap[abstractType.name]

        if map == nil {
            map = [:]

            if let unionType = abstractType as? GraphQLUnionType {
                for type in (try? unionType.getTypes()) ?? [] {
                    map?[type.name] = true
                }
            }

            if let interfaceType = abstractType as? GraphQLInterfaceType {
                let implementations = getImplementations(interfaceType: interfaceType)

                for type in implementations.objects {
                    map?[type.name] = true
                }

                for type in implementations.interfaces {
                    map?[type.name] = true
                }
            }

            subTypeMap[abstractType.name] = map
        }

        let isSubType = map?[maybeSubType.name] != nil
        return isSubType
    }

    public func getDirective(name: String) -> GraphQLDirective? {
        for directive in directives where directive.name == name {
            return directive
        }

        return nil
    }

    func toConfig() -> GraphQLSchemaNormalizedConfig {
        return GraphQLSchemaNormalizedConfig(
            description: description,
            query: queryType,
            mutation: mutationType,
            subscription: subscriptionType,
            types: Array(typeMap.values),
            directives: directives,
            extensions: extensions,
            astNode: astNode,
            extensionASTNodes: extensionASTNodes,
            assumeValid: validationErrors != nil
        )
    }
}

public typealias TypeMap = OrderedDictionary<String, GraphQLNamedType>

public struct InterfaceImplementations {
    public let objects: [GraphQLObjectType]
    public let interfaces: [GraphQLInterfaceType]

    public init(
        objects: [GraphQLObjectType] = [],
        interfaces: [GraphQLInterfaceType] = []
    ) {
        self.objects = objects
        self.interfaces = interfaces
    }
}

func collectImplementations(
    types: [GraphQLNamedType]
) throws -> [String: InterfaceImplementations] {
    var implementations: [String: InterfaceImplementations] = [:]

    for type in types {
        if let type = type as? GraphQLInterfaceType {
            if implementations[type.name] == nil {
                implementations[type.name] = InterfaceImplementations()
            }

            // Store implementations by interface.
            for iface in try type.getInterfaces() {
                implementations[iface.name] = InterfaceImplementations(
                    interfaces: (implementations[iface.name]?.interfaces ?? []) + [type]
                )
            }
        }

        if let type = type as? GraphQLObjectType {
            // Store implementations by objects.
            for iface in try type.getInterfaces() {
                implementations[iface.name] = InterfaceImplementations(
                    objects: (implementations[iface.name]?.objects ?? []) + [type]
                )
            }
        }
    }

    return implementations
}

func typeMapReducer(typeMap: TypeMap, type: GraphQLType) throws -> TypeMap {
    var typeMap = typeMap

    if let type = type as? GraphQLWrapperType {
        return try typeMapReducer(typeMap: typeMap, type: type.wrappedType)
    }

    guard let type = type as? GraphQLNamedType else {
        return typeMap // Should never happen
    }

    if let existingType = typeMap[type.name] {
        if existingType is GraphQLTypeReference {
            if type is GraphQLTypeReference {
                // Just short circuit because they're both type references
                return typeMap
            }
            // Otherwise, fall through and override the type reference
        } else {
            if type is GraphQLTypeReference {
                // Just ignore the reference and keep the concrete one
                return typeMap
            } else if !(existingType == type) {
                throw GraphQLError(
                    message:
                    "Schema must contain unique named types but contains multiple " +
                        "types named \"\(type.name)\"."
                )
            } else {
                // Otherwise, it's already been defined so short circuit
                return typeMap
            }
        }
    }

    typeMap[type.name] = type

    if let type = type as? GraphQLUnionType {
        typeMap = try type.getTypes().reduce(typeMap, typeMapReducer)
    }

    if let type = type as? GraphQLObjectType {
        typeMap = try type.getInterfaces().reduce(typeMap, typeMapReducer)

        for (_, field) in try type.getFields() {
            if !field.args.isEmpty {
                let fieldArgTypes = field.args.map { $0.type }
                typeMap = try fieldArgTypes.reduce(typeMap, typeMapReducer)
            }

            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    if let type = type as? GraphQLInterfaceType {
        typeMap = try type.getInterfaces().reduce(typeMap, typeMapReducer)

        for (_, field) in try type.getFields() {
            if !field.args.isEmpty {
                let fieldArgTypes = field.args.map { $0.type }
                typeMap = try fieldArgTypes.reduce(typeMap, typeMapReducer)
            }

            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    if let type = type as? GraphQLInputObjectType {
        for (_, field) in try type.getFields() {
            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    return typeMap
}

func replaceTypeReferences(typeMap: TypeMap) throws {
    for type in typeMap {
        if let typeReferenceContainer = type.value as? GraphQLTypeReferenceContainer {
            try typeReferenceContainer.replaceTypeReferences(typeMap: typeMap)
        }
    }

    // Check that no type names map to TypeReferences. That is, they have all been resolved to
    // actual types.
    for (typeName, graphQLNamedType) in typeMap {
        if graphQLNamedType is GraphQLTypeReference {
            throw GraphQLError(
                message: "Type \"\(typeName)\" was referenced but not defined."
            )
        }
    }
}

func resolveTypeReference(type: GraphQLType, typeMap: TypeMap) throws -> GraphQLType {
    if let type = type as? GraphQLTypeReference {
        guard let resolvedType = typeMap[type.name] else {
            throw GraphQLError(
                message: "Type \"\(type.name)\" not found in schema."
            )
        }

        return resolvedType
    }

    if let type = type as? GraphQLList {
        return try type.replaceTypeReferences(typeMap: typeMap)
    }

    if let type = type as? GraphQLNonNull {
        return try type.replaceTypeReferences(typeMap: typeMap)
    }

    return type
}

func resolveTypeReferences(types: [GraphQLType], typeMap: TypeMap) throws -> [GraphQLType] {
    var resolvedTypes: [GraphQLType] = []

    for type in types {
        try resolvedTypes.append(resolveTypeReference(type: type, typeMap: typeMap))
    }

    return resolvedTypes
}

class GraphQLSchemaNormalizedConfig {
    var description: String?
    var query: GraphQLObjectType?
    var mutation: GraphQLObjectType?
    var subscription: GraphQLObjectType?
    var types: [GraphQLNamedType]
    var directives: [GraphQLDirective]
    var extensions: [GraphQLSchemaExtensions]
    var astNode: SchemaDefinition?
    var extensionASTNodes: [SchemaExtensionDefinition]
    var assumeValid: Bool

    init(
        description: String? = nil,
        query: GraphQLObjectType? = nil,
        mutation: GraphQLObjectType? = nil,
        subscription: GraphQLObjectType? = nil,
        types: [GraphQLNamedType] = [],
        directives: [GraphQLDirective] = [],
        extensions: [GraphQLSchemaExtensions] = [],
        astNode: SchemaDefinition? = nil,
        extensionASTNodes: [SchemaExtensionDefinition] = [],
        assumeValid: Bool = false
    ) {
        self.description = description
        self.query = query
        self.mutation = mutation
        self.subscription = subscription
        self.types = types
        self.directives = directives
        self.extensions = extensions
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
        self.assumeValid = assumeValid
    }
}

/**
 * Custom extensions
 *
 * @remarks
 * Use a unique identifier name for your extension, for example the name of
 * your library or project. Do not use a shortened identifier as this increases
 * the risk of conflicts. We recommend you add at most one extension field,
 * an object which can contain all the values you need.
 */
public typealias GraphQLSchemaExtensions = [String: String]?
