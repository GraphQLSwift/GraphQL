enum BuildClientSchemaError: Error {
    case invalid(String)
}
public func buildClientSchema(introspection: IntrospectionQuery) throws -> GraphQLSchema {
    let schemaIntrospection = introspection.__schema
    var typeMap = [String: GraphQLNamedType]()
    typeMap = try schemaIntrospection.types.reduce(into: [String: GraphQLNamedType]()) {
        $0[$1.x.name] = try buildType($1.x)
    }
    
    
    // Include standard types only if they are used
    for stdType in specifiedScalarTypes + introspectionTypes {
        if (typeMap[stdType.name] != nil) {
            typeMap[stdType.name] = stdType
        }
    }
    
    func getNamedType(name: String) throws -> GraphQLNamedType {
        guard let type = typeMap[name] else {
            throw BuildClientSchemaError.invalid("Couldn't find type named \(name)")
        }
        return type
    }

    func buildImplementationsList(interfaces: [IntrospectionTypeRef]) throws -> [GraphQLInterfaceType] {
        try interfaces.map {
            switch $0 {
            case .named(_, let name):
                return try getInterfaceType(name: name)
            default:
                throw BuildClientSchemaError.invalid("Expected named type ref")
            }
        }
    }
    
    func getInterfaceType(name: String) throws -> GraphQLInterfaceType {
        guard let type = try getNamedType(name: name) as? GraphQLInterfaceType else {
            throw BuildClientSchemaError.invalid("Expected interface type")
        }
        return type
    }
    
    func getType(_ typeRef: IntrospectionTypeRef) throws -> GraphQLType {
        switch typeRef {
        case .list(let ofType):
            return GraphQLList(try getType(ofType))
        case .nonNull(let ofType):
            guard let type = try getType(ofType) as? GraphQLNullableType else {
                throw BuildClientSchemaError.invalid("Expected nullable type")
            }
            return GraphQLNonNull(type)
        case .named(_, let name):
            return try getNamedType(name: name)
        }
    }
    
    func buildFieldDefMap(fields: [IntrospectionField]) throws -> GraphQLFieldMap {
        try fields.reduce(
            into: GraphQLFieldMap()) {
                guard let type = try getType($1.type) as? GraphQLOutputType else {
                    throw BuildClientSchemaError.invalid("Introspection must provide output type for fields")
                }
                $0[$1.name] = GraphQLField(
                    type: type,
                    description: $1.description,
                    deprecationReason: $1.deprecationReason,
                    args: try buildInputValueDefMap(args: $1.args)
                )
            }
    }
    
    func buildInputValueDefMap(args: [IntrospectionInputValue]) throws -> GraphQLArgumentConfigMap {
        return try args.reduce(into: GraphQLArgumentConfigMap()) {
            $0[$1.name] = try buildInputValue(inputValue: $1)
        }
    }
    
    func buildInputValue(inputValue: IntrospectionInputValue) throws -> GraphQLArgument {
        guard let type = try getType(inputValue.type) as? GraphQLInputType else {
            throw BuildClientSchemaError.invalid("Introspection must provide input type for arguments")
        }
        let defaultValue = try inputValue.defaultValue.map {
            try valueFromAST(valueAST: parseValue(source: $0), type: type)
        }
        return GraphQLArgument(type: type, description: inputValue.description, defaultValue: defaultValue)
    }

    func buildType(_ type: IntrospectionType) throws -> GraphQLNamedType {
        switch type {
        case let type as IntrospectionScalarType:
            return try GraphQLScalarType(
                name: type.name,
                description: type.description,
                serialize: { try map(from: $0) }
            )
        case let type as IntrospectionObjectType:
            return try GraphQLObjectType(
                name: type.name,
                description: type.description,
                fields: { try! buildFieldDefMap(fields: type.fields ?? []) },
                interfaces: { try! buildImplementationsList(interfaces: type.interfaces ?? []) }
            )
        case let type as IntrospectionInterfaceType:
            return try GraphQLInterfaceType(
                name: type.name,
                description: type.description,
                interfaces: { try buildImplementationsList(interfaces: type.interfaces ?? []) },
                fields: { try! buildFieldDefMap(fields: type.fields ?? []) },
                resolveType: nil
            )
        case let type as IntrospectionUnionType:
            return try GraphQLUnionType(
                name: type.name,
                description: type.description,
                types: { try! type.possibleTypes.map(getObjectType) }
            )
        case let type as IntrospectionEnumType:
            return try GraphQLEnumType(
                name: type.name,
                description: type.description,
                values: type.enumValues.reduce(into: GraphQLEnumValueMap()) {
                    $0[$1.name] = GraphQLEnumValue(
                        value: Map.null,
                        description: $1.description,
                        deprecationReason: $1.deprecationReason
                    )
                }
            )
//        case .scalar:
//            return GraphQLScalarType(name: type["name"].string!, description: type["description"].string)
//        case .object:
//            return GraphQLObjectType(name: type["name"].string!, description: type["description"].string, fields: buildFieldDefMap(type: type), interfaces: buildImplementationsList(type))
        default:
            fatalError()
        }
    }
                
    func getObjectType(_ type: IntrospectionTypeRef) throws -> GraphQLObjectType {
        guard case .named(_, let name) = type else {
            throw BuildClientSchemaError.invalid("Expected name ref")
        }
        return try getObjectType(name: name)
    }
    
    func getObjectType(name: String) throws -> GraphQLObjectType {
        guard let type = try getNamedType(name: name) as? GraphQLObjectType else {
            throw BuildClientSchemaError.invalid("Expected object type")
        }
        return type
    }
    
//    let directives = []
    
    let mutationType: GraphQLObjectType?
    if let mutationTypeRef = schemaIntrospection.mutationType {
        mutationType = try getObjectType(name: mutationTypeRef.name)
    } else {
        mutationType = nil
    }
    
    return try GraphQLSchema(
        query: try getObjectType(name: schemaIntrospection.queryType.name),
        mutation: mutationType,
        subscription: nil,
        types: Array(typeMap.values),
        directives: []
    )
}
