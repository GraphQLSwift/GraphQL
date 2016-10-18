




//public enum Map {
//    case yo
//}
//
//public struct Schema {
//    let query: ObjectType
//
//    public init(query: ObjectType) {
//        self.query = query
//    }
//
//    public func execute(_ query: String) throws -> Map {
//        return .yo
//    }
//}

/**
 * Schema Definition
 *
 * A Schema is created by supplying the root types of each type of operation,
 * query and mutation (optional). A schema definition is then supplied to the
 * validator and executor.
 *
 * Example:
 *
 *     const MyAppSchema = new GraphQLSchema({
 *       query: MyAppQueryRootType,
 *       mutation: MyAppMutationRootType,
 *     })
 *
 * Note: If an array of `directives` are provided to GraphQLSchema, that will be
 * the exact list of directives represented and allowed. If `directives` is not
 * provided then a default set of the specified directives (e.g. @include and
 * @skip) will be used. If you wish to provide *additional* directives to these
 * specified directives, you must explicitly declare them. Example:
 *
 *     const MyAppSchema = new GraphQLSchema({
 *       ...
 *       directives: specifiedDirectives.concat([ myCustomDirective ]),
 *     })
 *
 */
public final class GraphQLSchema {
    let queryType: GraphQLObjectType
    let mutationType: GraphQLObjectType?
    let subscriptionType: GraphQLObjectType?
    let directives: [GraphQLDirective]
    let typeMap: TypeMap
    let implementations: [String: [GraphQLObjectType]]
    var possibleTypeMap: [String: [String: Bool]] = [:]

    public init(query: GraphQLObjectType, mutation: GraphQLObjectType? = nil, subscription: GraphQLObjectType? = nil, types: [GraphQLNamedType] = [], directives: [GraphQLDirective] = []) throws {
        self.queryType = query
        self.mutationType = mutation
        self.subscriptionType = subscription

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

        //initialTypes.append(__Schema)

        if !types.isEmpty {
            initialTypes.append(contentsOf: types)
        }

        var map = TypeMap()

        for type in initialTypes {
            map = try typeMapReducer(map: map, type: type)
        }

        self.typeMap = map

        // Keep track of all implementations by interface name.
        var implementations: [String: [GraphQLObjectType]] = [:]

        for (_, type) in typeMap {
            if let object = type as? GraphQLObjectType {
                for interface in object.interfaces {
                    if var i = implementations[interface.name] {
                        i.append(object)
                        implementations[interface.name] = i
                    } else {
                        implementations[interface.name] = [object]
                    }
                }
            }
        }

        self.implementations = implementations

        // Enforce correct interface implementations.
        for (_, type) in typeMap {
            if let object = type as? GraphQLObjectType {
                for interface in object.interfaces {
                    try assert(object: object, implementsInterface: interface, schema: self)
                }
            }
        }
    }

    func getType(name: String) -> GraphQLNamedType? {
        return typeMap[name]
    }

    func getPossibleTypes(abstractType: GraphQLAbstractType) -> [GraphQLObjectType] {
        if let union = abstractType as? GraphQLUnionType {
            return union.types
        }

        if let interface = abstractType as? GraphQLInterfaceType {
            return implementations[interface.name] ?? []
        }

        // Should be impossible. Only UnionType and InterfaceType should conform to AbstractType
        return []
    }

    func isPossibleType(abstractType: GraphQLAbstractType, possibleType: GraphQLObjectType) -> Bool {
        if possibleTypeMap[abstractType.name] == nil {
            let possibleTypes = getPossibleTypes(abstractType: abstractType)

            guard !possibleTypes.isEmpty else {
                let error = "Could not find possible implementing types for \(abstractType.name) " +
                    "in schema. Check that schema.types is defined and is an array of " +
                "all possible types in the schema."
                return false

            }

            var map: [String: Bool] = [:]

            for type in possibleTypes {
                map[type.name] = true
            }

            possibleTypeMap[abstractType.name] = map
        }

        return possibleTypeMap[abstractType.name]?[possibleType.name] != nil
    }


    func getDirective(name: String) -> GraphQLDirective? {
        for directive in directives where directive.name == name {
            return directive
        }
        return nil
    }
}

public typealias TypeMap = [String: GraphQLNamedType]

public enum SchemaError : Error {
    //    'Schema must contain unique named types but contains multiple ' +
    //    `types named "${type.name}".`
    case multipleTypesWithTheSameName
}

func typeMapReducer(map: TypeMap, type: GraphQLNamedType) throws -> TypeMap {
    //  if type is List || type is NonNull {
    //    return typeMapReducer(map: map, type: type.ofType)
    //  }

    //  guard map[type.name] == nil else {
    //    // check for identity
    //    throw SchemaError.multipleTypesWithTheSameName
    //  }

    //  map[type.name] = type

    var reducedMap = map

    //  if let union = type as? UnionType {
    //    reducedMap = type.getTypes().reduce(typeMapReducer, reducedMap)
    //  }

    //  if let object = type as? ObjectType {
    //    reducedMap = object.interfaces.reduce(typeMapReducer, reducedMap)
    //  }

    //  if type is ObjectType || type is InterfaceType {
    //    for (_, field) in type.fields {
    //
    //      if !field.args.isEmpty {
    //        let fieldArgTypes = field.args.map($0.type)
    //        reducedMap = fieldArgTypes.reduce(typeMapReducer, reducedMap)
    //      }
    //
    //      reducedMap = typeMapReducer(reducedMap, field.type)
    //    }
    //  }
    //
    //  if type is InputObjectType {
    //    for (_, field) in type.fields {
    //        reducedMap = typeMapReducer(reducedMap, field.type)
    //    }
    //  }

    return reducedMap
}

public enum InterfaceImplementationError : Error {
    case noImplementation(String)
}

func assert(object: GraphQLObjectType, implementsInterface interface: GraphQLInterfaceType, schema: GraphQLSchema) throws {
    let objectFieldMap = object.fields
    let ifaceFieldMap = interface.fields

    for (fieldName, ifaceField) in ifaceFieldMap {
        guard let objectField = objectFieldMap[fieldName] else {
            throw InterfaceImplementationError.noImplementation("\(interface.name) expects field \(fieldName) but \(object.name) does not provide it.")
        }

    }

    //    // Assert interface field type is satisfied by object field type, by being
    //    // a valid subtype. (covariant)
    //    invariant(
    //      isTypeSubTypeOf(schema, objectField.type, ifaceField.type),
    //      `${iface.name}.${fieldName} expects type "${String(ifaceField.type)}" ` +
    //      'but ' +
    //      `${object.name}.${fieldName} provides type "${String(objectField.type)}".`
    //    );
    //
    //    // Assert each interface field arg is implemented.
    //    ifaceField.args.forEach(ifaceArg => {
    //      const argName = ifaceArg.name;
    //      const objectArg = find(objectField.args, arg => arg.name === argName);
    //
    //      // Assert interface field arg exists on object field.
    //      invariant(
    //        objectArg,
    //        `${iface.name}.${fieldName} expects argument "${argName}" but ` +
    //        `${object.name}.${fieldName} does not provide it.`
    //      );
    //
    //      // Assert interface field arg type matches object field arg type.
    //      // (invariant)
    //      invariant(
    //        isEqualType(ifaceArg.type, objectArg.type),
    //        `${iface.name}.${fieldName}(${argName}:) expects type ` +
    //        `"${String(ifaceArg.type)}" but ` +
    //        `${object.name}.${fieldName}(${argName}:) provides type ` +
    //        `"${String(objectArg.type)}".`
    //      );
    //    });
    //
    //    // Assert additional arguments must not be required.
    //    objectField.args.forEach(objectArg => {
    //      const argName = objectArg.name;
    //      const ifaceArg = find(ifaceField.args, arg => arg.name === argName);
    //      if (!ifaceArg) {
    //        invariant(
    //          !(objectArg.type instanceof GraphQLNonNull),
    //          `${object.name}.${fieldName}(${argName}:) is of required type ` +
    //          `"${String(objectArg.type)}" but is not also provided by the ` +
    //          `interface ${iface.name}.${fieldName}.`
    //        );
    //      }
    //    });
    //  });
}
