import Dispatch
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
public final class GraphQLSchema: @unchecked Sendable {
    let description: String?
    let extensions: [GraphQLSchemaExtensions]
    let astNode: SchemaDefinition?
    let extensionASTNodes: [SchemaExtensionDefinition]

    // Used as a cache for validateSchema().
    private var _validationErrors: [GraphQLError]?
    private let validationErrorQueue = DispatchQueue(
        label: "graphql.schema.validationerrors",
        attributes: .concurrent
    )
    var validationErrors: [GraphQLError]? {
        get {
            // Reads can occur concurrently.
            return validationErrorQueue.sync {
                _validationErrors
            }
        }
        set {
            // Writes occur sequentially.
            return validationErrorQueue.sync(flags: .barrier) {
                self._validationErrors = newValue
            }
        }
    }

    public let queryType: GraphQLObjectType?
    public let mutationType: GraphQLObjectType?
    public let subscriptionType: GraphQLObjectType?
    public let directives: [GraphQLDirective]
    public let typeMap: TypeMap
    public let implementations: [String: InterfaceImplementations]

    // Used as a cache for validateSchema().
    private var _subTypeMap: [String: [String: Bool]] = [:]
    private let subTypeMapQueue = DispatchQueue(
        label: "graphql.schema.subtypeMap",
        attributes: .concurrent
    )
    var subTypeMap: [String: [String: Bool]] {
        get {
            // Reads can occur concurrently.
            return subTypeMapQueue.sync {
                _subTypeMap
            }
        }
        set {
            // Writes occur sequentially.
            return subTypeMapQueue.sync(flags: .barrier) {
                self._subTypeMap = newValue
            }
        }
    }

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
        _validationErrors = assumeValid ? [] : nil

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

        // Storing the resulting map for reference by the schema.
        var typeMap = TypeMap()

        // Keep track of all implementations by interface name.
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
        var implementations = try collectImplementations(types: Array(typeMap.values))

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
                    let implementation = implementations[iface.name] ?? .init(
                        objects: [],
                        interfaces: []
                    )

                    var interfaces = implementation.interfaces
                    interfaces.append(namedType)
                    implementations[iface.name] = .init(
                        objects: implementation.objects,
                        interfaces: interfaces
                    )
                }
            } else if let namedType = namedType as? GraphQLObjectType {
                // Store implementations by objects.
                for iface in try namedType.getInterfaces() {
                    let implementation = implementations[iface.name] ?? .init(
                        objects: [],
                        interfaces: []
                    )

                    var objects = implementation.objects
                    objects.append(namedType)
                    implementations[iface.name] = .init(
                        objects: objects,
                        interfaces: implementation.interfaces
                    )
                }
            }
        }

        self.typeMap = typeMap
        self.implementations = implementations
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

public struct InterfaceImplementations: Sendable {
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

func typeMapReducer(typeMap: TypeMap, type: GraphQLType) throws -> TypeMap {
    var typeMap = typeMap

    if let type = type as? GraphQLWrapperType {
        return try typeMapReducer(typeMap: typeMap, type: type.wrappedType)
    }

    guard let type = type as? GraphQLNamedType else {
        return typeMap // Should never happen
    }

    if let existingType = typeMap[type.name] {
        if !(existingType == type) {
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
