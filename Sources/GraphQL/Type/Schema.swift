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
    public let queryType: GraphQLObjectType
    public let mutationType: GraphQLObjectType?
    public let subscriptionType: GraphQLObjectType?
    public let directives: [GraphQLDirective]
    public let typeMap: TypeMap
    public let implementations: [String: InterfaceImplementations]
    private var subTypeMap: [String: [String: Bool]] = [:]

    public init(
        query: GraphQLObjectType,
        mutation: GraphQLObjectType? = nil,
        subscription: GraphQLObjectType? = nil,
        types: [GraphQLNamedType] = [],
        directives: [GraphQLDirective] = []
    ) throws {
        queryType = query
        mutationType = mutation
        subscriptionType = subscription

        // Provide specified directives (e.g. @include and @skip) by default.
        self.directives = directives.isEmpty ? specifiedDirectives : directives

        // Build type map now to detect any errors within this schema.
        var initialTypes: [GraphQLNamedType] = [
            queryType,
        ]

        if let mutation = mutationType {
            initialTypes.append(mutation)
        }

        if let subscription = subscriptionType {
            initialTypes.append(subscription)
        }

        initialTypes.append(__Schema)

        if !types.isEmpty {
            initialTypes.append(contentsOf: types)
        }

        var typeMap = TypeMap()

        for type in initialTypes {
            typeMap = try typeMapReducer(typeMap: typeMap, type: type)
        }

        self.typeMap = typeMap
        try replaceTypeReferences(typeMap: typeMap)

        // Keep track of all implementations by interface name.
        implementations = collectImplementations(types: Array(typeMap.values))

        // Enforce correct interface implementations.
        for (_, type) in typeMap {
            if let object = type as? GraphQLObjectType {
                for interface in object.interfaces {
                    try assert(object: object, implementsInterface: interface, schema: self)
                }
            }
        }
    }

    public func getType(name: String) -> GraphQLNamedType? {
        return typeMap[name]
    }

    public func getPossibleTypes(abstractType: GraphQLAbstractType) -> [GraphQLObjectType] {
        if let unionType = abstractType as? GraphQLUnionType {
            return unionType.types
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
                for type in unionType.types {
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
}

extension GraphQLSchema: Encodable {
    private enum CodingKeys: String, CodingKey {
        case queryType
        case mutationType
        case subscriptionType
        case directives
    }
}

public typealias TypeMap = [String: GraphQLNamedType]

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
) -> [String: InterfaceImplementations] {
    var implementations: [String: InterfaceImplementations] = [:]

    for type in types {
        if let type = type as? GraphQLInterfaceType {
            if implementations[type.name] == nil {
                implementations[type.name] = InterfaceImplementations()
            }

            // Store implementations by interface.
            for iface in type.interfaces {
                implementations[iface.name] = InterfaceImplementations(
                    interfaces: (implementations[iface.name]?.interfaces ?? []) + [type]
                )
            }
        }

        if let type = type as? GraphQLObjectType {
            // Store implementations by objects.
            for iface in type.interfaces {
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

    guard typeMap[type.name] == nil || typeMap[type.name] is GraphQLTypeReference else {
        guard typeMap[type.name]! == type || type is GraphQLTypeReference else {
            throw GraphQLError(
                message:
                "Schema must contain unique named types but contains multiple " +
                    "types named \"\(type.name)\"."
            )
        }

        return typeMap
    }

    typeMap[type.name] = type

    if let type = type as? GraphQLUnionType {
        typeMap = try type.types.reduce(typeMap, typeMapReducer)
    }

    if let type = type as? GraphQLObjectType {
        typeMap = try type.interfaces.reduce(typeMap, typeMapReducer)

        for (_, field) in type.fields {
            if !field.args.isEmpty {
                let fieldArgTypes = field.args.map { $0.type }
                typeMap = try fieldArgTypes.reduce(typeMap, typeMapReducer)
            }

            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    if let type = type as? GraphQLInterfaceType {
        typeMap = try type.interfaces.reduce(typeMap, typeMapReducer)

        for (_, field) in type.fields {
            if !field.args.isEmpty {
                let fieldArgTypes = field.args.map { $0.type }
                typeMap = try fieldArgTypes.reduce(typeMap, typeMapReducer)
            }

            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    if let type = type as? GraphQLInputObjectType {
        for (_, field) in type.fields {
            typeMap = try typeMapReducer(typeMap: typeMap, type: field.type)
        }
    }

    return typeMap
}

func assert(
    object: GraphQLObjectType,
    implementsInterface interface: GraphQLInterfaceType,
    schema: GraphQLSchema
) throws {
    let objectFieldMap = object.fields
    let interfaceFieldMap = interface.fields

    for (fieldName, interfaceField) in interfaceFieldMap {
        guard let objectField = objectFieldMap[fieldName] else {
            throw GraphQLError(
                message:
                "\(interface.name) expects field \(fieldName) " +
                    "but \(object.name) does not provide it."
            )
        }

        // Assert interface field type is satisfied by object field type, by being
        // a valid subtype. (covariant)
        guard try isTypeSubTypeOf(schema, objectField.type, interfaceField.type) else {
            throw GraphQLError(
                message:
                "\(interface.name).\(fieldName) expects type \"\(interfaceField.type)\" " +
                    "but " +
                    "\(object.name).\(fieldName) provides type \"\(objectField.type)\"."
            )
        }

        // Assert each interface field arg is implemented.
        for interfaceArg in interfaceField.args {
            let argName = interfaceArg.name
            guard let objectArg = objectField.args.find({ $0.name == argName }) else {
                throw GraphQLError(
                    message:
                    "\(interface.name).\(fieldName) expects argument \"\(argName)\" but " +
                        "\(object.name).\(fieldName) does not provide it."
                )
            }

            // Assert interface field arg type matches object field arg type.
            // (invariant)
            guard isEqualType(interfaceArg.type, objectArg.type) else {
                throw GraphQLError(
                    message:
                    "\(interface.name).\(fieldName)(\(argName):) expects type " +
                        "\"\(interfaceArg.type)\" but " +
                        "\(object.name).\(fieldName)(\(argName):) provides type " +
                        "\"\(objectArg.type)\"."
                )
            }
        }

        // Assert additional arguments must not be required.
        for objectArg in objectField.args {
            let argName = objectArg.name
            if
                interfaceField.args.find({ $0.name == argName }) == nil,
                isRequiredArgument(objectArg)
            {
                throw GraphQLError(
                    message:
                    "\(object.name).\(fieldName) includes required argument (\(argName):) that is missing " +
                        "from the Interface field \(interface.name).\(fieldName)."
                )
            }
        }
    }
}

func replaceTypeReferences(typeMap: TypeMap) throws {
    for type in typeMap {
        if let typeReferenceContainer = type.value as? GraphQLTypeReferenceContainer {
            try typeReferenceContainer.replaceTypeReferences(typeMap: typeMap)
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
