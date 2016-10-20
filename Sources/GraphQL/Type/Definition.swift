/**
 * These are all of the possible kinds of types.
 */
public protocol GraphQLType : CustomStringConvertible {}
//    GraphQLScalarType |
//    GraphQLObjectType |
//    GraphQLInterfaceType |
//    GraphQLUnionType |
//    GraphQLEnumType |
//    GraphQLInputObjectType |
//    GraphQLList<any> |
//    GraphQLNonNull<any>;

func isType(type: Any) -> Bool {
    return type is GraphQLType
}

/**
 * These types may be used as input types for arguments and directives.
 */
public protocol GraphQLInputType : GraphQLType {}
//    GraphQLScalarType |
//    GraphQLEnumType |
//    GraphQLInputObjectType |
//    GraphQLList<GraphQLInputType> |
//    GraphQLNonNull<GraphQLScalarType | GraphQLEnumType | GraphQLInputObjectType | GraphQLList<GraphQLInputType>>

func isInputType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)

    return namedType is GraphQLScalarType ||
        namedType is GraphQLEnumType ||
        namedType is GraphQLInputObjectType
}

/**
 * These types may be used as output types as the result of fields.
 */
public protocol GraphQLOutputType : GraphQLType {}
//    GraphQLScalarType |
//    GraphQLObjectType |
//    GraphQLInterfaceType |
//    GraphQLUnionType |
//    GraphQLEnumType |
//    GraphQLList<GraphQLOutputType> |
//    GraphQLNonNull<GraphQLScalarType | GraphQLObjectType | GraphQLInterfaceType | GraphQLUnionType | GraphQLEnumType | GraphQLList<GraphQLOutputType>>

func isOutputType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)

    return namedType is GraphQLScalarType ||
        namedType is GraphQLObjectType ||
        namedType is GraphQLInterfaceType ||
        namedType is GraphQLUnionType ||
        namedType is GraphQLEnumType
}

/**
 * These types may describe types which may be leaf values.
 */
public protocol GraphQLLeafType : GraphQLType {
    var name: String { get }
    func serialize(value: Map) throws -> Map?
    func parseValue(value: Map) throws -> Map?
    func parseLiteral(valueAST: Value) throws -> Map?
}
// GraphQLScalarType
// GraphQLEnumType

func isLeafType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)
    return namedType is GraphQLScalarType || namedType is GraphQLEnumType
}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLCompositeType : GraphQLType, GraphQLNamedType, GraphQLOutputType {}
//    GraphQLObjectType |
//    GraphQLInterfaceType |
//    GraphQLUnionType;

func isCompositeType(type: GraphQLType?) -> Bool {
    return type is GraphQLObjectType ||
        type is GraphQLInterfaceType ||
        type is GraphQLUnionType
}

protocol GraphQLFieldsContainer : GraphQLNamedType {
    func replaceTypeReferences(typeMap: TypeMap) throws -> Self
}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLAbstractType : GraphQLNamedType {
    var resolveType: GraphQLTypeResolve? { get }
}
//    GraphQLInterfaceType |
//    GraphQLUnionType;

func isAbstractType(type: GraphQLType?) -> Bool {
    return type is GraphQLInterfaceType ||
        type is GraphQLUnionType
}

/**
 * These types can all accept null as a value.
 */
public protocol GraphQLNullableType : GraphQLType {}
//    GraphQLScalarType |
//    GraphQLObjectType |
//    GraphQLInterfaceType |
//    GraphQLUnionType |
//    GraphQLEnumType |
//    GraphQLInputObjectType |
//    GraphQLList<*>;

func getNullableType(type: GraphQLType?) -> GraphQLNullableType? {
    if let type = type as? GraphQLNonNull {
        return type.ofType
    }

    return type as? GraphQLNullableType
}

/**
 * These named types do not include modifiers like List or NonNull.
 */
public protocol GraphQLNamedType : GraphQLNullableType {
    var name: String { get }
}
//    GraphQLScalarType |
//    GraphQLObjectType |
//    GraphQLInterfaceType |
//    GraphQLUnionType |
//    GraphQLEnumType |
//    GraphQLInputObjectType;

func getNamedType(type: GraphQLType?) -> GraphQLNamedType? {
    var unmodifiedType = type

    while let type = unmodifiedType as? GraphQLWrapperType {
        unmodifiedType = type.wrappedType
    }

    return unmodifiedType as? GraphQLNamedType
}

/**
 * These types wrap other types.
 */
protocol GraphQLWrapperType {
    var wrappedType: GraphQLType { get }
}
//    GraphQLList<any> |
//    GraphQLNonNull<any>;

/**
 * Scalar Type Definition
 *
 * The leaf values of any request and input values to arguments are
 * Scalars (or Enums) and are defined with a name and a series of functions
 * used to parse input from ast or variables and to ensure validity.
 *
 * Example:
 *
 *     let oddType = try ScalarType(name: "Odd", serialize: { $0 % 2 == 1 ? $0 : nil })
 *
 */
public struct GraphQLScalarType : GraphQLType, GraphQLInputType, GraphQLOutputType, CustomStringConvertible, GraphQLNullableType, GraphQLLeafType, GraphQLNamedType {
    public let name: String
    let scalarDescription: String?
    let serialize: (Map) throws -> Map?
    let parseValue: ((Map) throws -> Map?)?
    let parseLiteral: ((Value) throws -> Map?)?

    public init(name: String, description: String? = nil, serialize: @escaping (Map) throws -> Map?) throws {
        try assertValid(name: name)
        self.name = name
        self.scalarDescription = description
        self.serialize = serialize
        self.parseValue = nil
        self.parseLiteral = nil
    }

    init(name: String, description: String? = nil, serialize: @escaping (Map) throws -> Map?, parseValue: @escaping (Map) throws -> Map?, parseLiteral: @escaping (Value) throws -> Map?) throws {
        try assertValid(name: name)
        self.name = name
        self.scalarDescription = description
        self.serialize = serialize
        self.parseValue = parseValue
        self.parseLiteral = parseLiteral
    }

    // Serializes an internal value to include in a response.
    public func serialize(value: Map) throws -> Map? {
        return try self.serialize(value)
    }

    // Parses an externally provided value to use as an input.
    public func parseValue(value: Map) throws -> Map? {
        return try self.parseValue?(value)
    }

    // Parses an externally provided literal value to use as an input.
    public func parseLiteral(valueAST: Value) throws -> Map? {
        return try self.parseLiteral?(valueAST)
    }

    public var description: String {
        return name
    }
}

/**
 * Object Type Definition
 *
 * Almost all of the GraphQL types you define will be object types. Object types
 * have a name, but most importantly describe their fields.
 *
 * Example:
 *
 *     const AddressType = new GraphQLObjectType({
 *       name: 'Address',
 *       fields: {
 *         street: { type: GraphQLString },
 *         number: { type: GraphQLInt },
 *         formatted: {
 *           type: GraphQLString,
 *           resolve(obj) {
 *             return obj.number + ' ' + obj.street
 *           }
 *         }
 *       }
 *     });
 *
 * When two types need to refer to each other, or a type needs to refer to
 * itself in a field, you can use a function expression (aka a closure or a
 * thunk) to supply the fields lazily.
 *
 * Example:
 *
 *     const PersonType = new GraphQLObjectType({
 *       name: 'Person',
 *       fields: () => ({
 *         name: { type: GraphQLString },
 *         bestFriend: { type: PersonType },
 *       })
 *     });
 *
 */
public struct GraphQLObjectType : GraphQLNamedType, GraphQLOutputType, GraphQLCompositeType, GraphQLFieldsContainer {
    public let name: String
    let objectDescription: String?
    let fields: GraphQLFieldDefinitionMap
    let interfaces: [GraphQLInterfaceType]
    let isTypeOf: GraphQLIsTypeOf?

    public init(name: String, description: String? = nil, fields: GraphQLFieldConfigMap, interfaces: [GraphQLInterfaceType] = [], isTypeOf: GraphQLIsTypeOf? = nil) throws {
        try assertValid(name: name)
        self.name = name
        self.objectDescription = description
        self.fields = try defineFieldMap(type: GraphQLObjectType.self, fields: fields)
        self.interfaces = interfaces
        self.isTypeOf = isTypeOf
    }

    init(name: String, objectDescription: String?, fields: GraphQLFieldDefinitionMap, interfaces: [GraphQLInterfaceType], isTypeOf: GraphQLIsTypeOf?) {
        self.name = name
        self.objectDescription = objectDescription
        self.fields = fields
        self.interfaces = interfaces
        self.isTypeOf = isTypeOf
    }

    public var description: String {
        return name
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLObjectType {
        return GraphQLObjectType(
            name: name,
            objectDescription: objectDescription,
            fields: try fields.reduce([:]) { newFields, field in
                var newFields = newFields
                let resolvedField = try field.value.replaceTypeReferences(typeMap: typeMap)
                newFields[field.key] = resolvedField
                return newFields
            },
            interfaces: interfaces,
            isTypeOf: isTypeOf
        )
    }
}

public enum GraphQLObjectTypeError : Error {
    case invalidFields(String)
}

func defineFieldMap(type: GraphQLNamedType.Type, fields: GraphQLFieldConfigMap) throws -> GraphQLFieldDefinitionMap {
    guard !fields.isEmpty else {
        throw GraphQLObjectTypeError.invalidFields("\(type) fields must be an object with field names as keys or a function which returns such an object.")
    }

    var fieldMap = GraphQLFieldDefinitionMap()

    for (name, config) in fields {
        try assertValid(name: name)

        let field = GraphQLFieldDefinition(
            name: name,
            description: config.description,
            type: config.type,
            args: try defineArgumentMap(args: config.args),
            resolve: config.resolve,
            deprecationReason: config.deprecationReason
        )

        fieldMap[name] = field
    }

    return fieldMap
}

func defineArgumentMap(args: GraphQLArgumentConfigMap) throws -> GraphQLArgumentMap {
    var argumentMap = GraphQLArgumentMap()

    for (name, config) in args {
        try assertValid(name: name)
        let argument = GraphQLArgument(
            name: name,
            type: config.type,
            defaultValue: config.defaultValue,
            description: config.description
        )
        argumentMap[name] = argument
    }

    return argumentMap
}

//function defineInterfaces(
//    type: GraphQLObjectType,
//    interfacesThunk: Thunk<?Array<GraphQLInterfaceType>>
//): Array<GraphQLInterfaceType> {
//    const interfaces = resolveThunk(interfacesThunk);
//    if (!interfaces) {
//        return [];
//    }
//    invariant(
//        Array.isArray(interfaces),
//        `${type.name} interfaces must be an Array or a function which returns ` +
//        'an Array.'
//    );
//    interfaces.forEach(iface => {
//        invariant(
//            iface instanceof GraphQLInterfaceType,
//            `${type.name} may only implement Interface types, it cannot ` +
//            `implement: ${String(iface)}.`
//        );
//        if (typeof iface.resolveType !== 'function') {
//            invariant(
//                typeof type.isTypeOf === 'function',
//                `Interface Type ${iface.name} does not provide a "resolveType" ` +
//                `function and implementing Type ${type.name} does not provide a ` +
//                '"isTypeOf" function. There is no way to resolve this implementing ' +
//                'type during execution.'
//            );
//        }
//        });
//    return interfaces;
//}


public enum TypeResolveResult {
    case type(GraphQLObjectType)
    case name(String)
}

public typealias GraphQLTypeResolve = (_ value: Map, _ context: Map, _ info: GraphQLResolveInfo) throws -> TypeResolveResult

public typealias GraphQLIsTypeOf = (_ source: Map, _ context: Map, _ info: GraphQLResolveInfo) -> Bool

public typealias GraphQLFieldResolve = (_ source: Map, _ args: [String: Map], _ context: Map, _ info: GraphQLResolveInfo) throws -> Map

//public enum IndexPathElement {
//    case string(String)
//    case number(Int)
//}

public struct GraphQLResolveInfo {
    let fieldName: String
    let fieldASTs: [Field]
    let returnType: GraphQLOutputType
    let parentType: GraphQLCompositeType
    let path: [IndexPathElement]
    let schema: GraphQLSchema
    let fragments: [String: FragmentDefinition]
    let rootValue: Any
    let operation: OperationDefinition
    let variableValues: [String: Any]
}

public typealias GraphQLFieldConfigMap = [String: GraphQLFieldConfig]

public struct GraphQLFieldConfig {
    let type: GraphQLOutputType
    let args: GraphQLArgumentConfigMap
    let deprecationReason: String?
    let description: String?
    let resolve: GraphQLFieldResolve?

    public init(type: GraphQLOutputType, args: GraphQLArgumentConfigMap = [:], deprecationReason: String? = nil, description: String? = nil, resolve: GraphQLFieldResolve? = nil) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.resolve = resolve
    }
}

public typealias GraphQLFieldDefinitionMap = [String: GraphQLFieldDefinition]

public struct GraphQLFieldDefinition {
    let name: String
    let description: String?
    let type: GraphQLOutputType
    let args: GraphQLArgumentMap
    let resolve: GraphQLFieldResolve?
    let deprecationReason: String?

    var isDeprecated: Bool {
        return deprecationReason != nil
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLFieldDefinition {
        let resolvedType = try resolveTypeReference(type: type, typeMap: typeMap)

        guard let outputType = resolvedType as? GraphQLOutputType else {
            throw GraphQLError(message: "Resolved type \"\(resolvedType)\" is not a valid output type.")
        }

        return GraphQLFieldDefinition(
            name: name,
            description: description,
            type: outputType,
            args: args,
            resolve: resolve,
            deprecationReason: deprecationReason
        )
    }
}

public typealias GraphQLArgumentConfigMap = [String: GraphQLArgumentConfig]

public struct GraphQLArgumentConfig {
    let type: GraphQLInputType
    let description: String?
    let defaultValue: Map?

    public init(type: GraphQLInputType, description: String? = nil, defaultValue: Map? = nil) {
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
    }
}

public typealias GraphQLArgumentMap = [String: GraphQLArgument]

public struct GraphQLArgument {
    let name: String
    let type: GraphQLInputType
    let defaultValue: Map?
    let description: String?
}

/**
 * Interface Type Definition
 *
 * When a field can return one of a heterogeneous set of types, a Interface type
 * is used to describe what types are possible, what fields are in common across
 * all types, as well as a function to determine which type is actually used
 * when the field is resolved.
 *
 * Example:
 *
 *     const EntityType = new GraphQLInterfaceType({
 *       name: 'Entity',
 *       fields: {
 *         name: { type: GraphQLString }
 *       }
 *     });
 *
 */
public struct GraphQLInterfaceType : GraphQLAbstractType, GraphQLCompositeType, GraphQLFieldsContainer {
    public let name: String
    let interfaceDescription: String?
    public let resolveType: GraphQLTypeResolve?

    let fields: GraphQLFieldDefinitionMap

    public init(name: String, description: String? = nil, fields: GraphQLFieldConfigMap, resolveType: GraphQLTypeResolve? = nil) throws {
        try assertValid(name: name)
        self.name = name
        self.interfaceDescription = description
        self.fields = try defineFieldMap(type: GraphQLInterfaceType.self, fields: fields)
        self.resolveType = resolveType
    }

    init(name: String, interfaceDescription: String?, fields: GraphQLFieldDefinitionMap, resolveType: GraphQLTypeResolve?) {
        self.name = name
        self.interfaceDescription = interfaceDescription
        self.fields = fields
        self.resolveType = resolveType
    }

    public var description: String {
        return name
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLInterfaceType {
        return GraphQLInterfaceType(
            name: name,
            interfaceDescription: interfaceDescription,
            fields: try fields.reduce([:]) { newFields, field in
                var newFields = newFields
                let resolvedField = try field.value.replaceTypeReferences(typeMap: typeMap)
                newFields[field.key] = resolvedField
                return newFields
            },
            resolveType: resolveType
        )
    }
}

/**
 * Union Type Definition
 *
 * When a field can return one of a heterogeneous set of types, a Union type
 * is used to describe what types are possible as well as providing a function
 * to determine which type is actually used when the field is resolved.
 *
 * Example:
 *
 *     const PetType = new GraphQLUnionType({
 *       name: 'Pet',
 *       types: [ DogType, CatType ],
 *       resolveType(value) {
 *         if (value instanceof Dog) {
 *           return DogType;
 *         }
 *         if (value instanceof Cat) {
 *           return CatType;
 *         }
 *       }
 *     });
 *
 */
struct GraphQLUnionType : GraphQLAbstractType, GraphQLCompositeType {
    public let name: String
    let unionDescription: String?
    let resolveType: GraphQLTypeResolve?

    let types: [GraphQLObjectType]
    let possibleTypeNames: [String: Bool]

    init(name: String, description: String? = nil, resolveType: GraphQLTypeResolve? = nil, types: [GraphQLObjectType]) throws {
        try assertValid(name: name)
        self.name = name
        self.unionDescription = description
        self.resolveType = resolveType
        self.types = try defineTypes(hasResolve: resolveType != nil, types: types)
        self.possibleTypeNames = [:]
    }

    var description: String {
        return name
    }
}

func defineTypes(hasResolve: Bool, types: [GraphQLObjectType]) throws -> [GraphQLObjectType] {
    guard !types.isEmpty else {
        return []
        //    invariant(
        //        Array.isArray(types) && types.length > 0,
        //        'Must provide Array of types or a function which returns ' +
        //        `such an array for Union ${unionType.name}.`
        //    );
    }

    if !hasResolve {
        for type in types {
            guard type.isTypeOf != nil else {
                return []
                //            invariant(
                //                typeof type.isTypeOf === 'function',
                //                `Union type "${unionType.name}" does not provide a "resolveType" ` +
                //                `function and possible type "${objType.name}" does not provide an ` +
                //                '"isTypeOf" function. There is no way to resolve this possible type ' +
                //                'during execution.'
                //            );
            }
        }
    }

    return types
}

/**
 * Enum Type Definition
 *
 * Some leaf values of requests and input values are Enums. GraphQL serializes
 * Enum values as strings, however internally Enums can be represented by any
 * kind of type, often integers.
 *
 * Example:
 *
 *     const RGBType = new GraphQLEnumType({
 *       name: 'RGB',
 *       values: {
 *         RED: { value: 0 },
 *         GREEN: { value: 1 },
 *         BLUE: { value: 2 }
 *       }
 *     });
 *
 * Note: If a value is not provided in a definition, the name of the enum value
 * will be used as its internal value.
 */
public struct GraphQLEnumType : GraphQLType, GraphQLLeafType, GraphQLInputType {
    public let name: String
    let enumDescription: String?

    let values: [GraphQLEnumValueDefinition]
    let valueLookup: [Map: GraphQLEnumValueDefinition]
    let nameLookup: [String: GraphQLEnumValueDefinition]

    public init(name: String, description: String? = nil, values: GraphQLEnumValueConfigMap) throws {
        try assertValid(name: name)
        self.name = name
        self.enumDescription = description
        self.values = try defineEnumValues(valueMap: values)

        var valueLookup: [Map: GraphQLEnumValueDefinition] = [:]

        for value in self.values {
            valueLookup[value.value] = value
        }

        self.valueLookup = valueLookup

        var nameLookup: [String: GraphQLEnumValueDefinition] = [:]

        for value in self.values {
            nameLookup[value.name] = value
        }

        self.nameLookup = nameLookup
    }

    public func serialize(value: Map) -> Map? {
        return valueLookup[value].map({ .string($0.name) })
    }

    public func parseValue(value: Map) -> Map? {
        if case .string(let value) = value {
            return nameLookup[value]?.value
        }
        return nil
    }

    public func parseLiteral(valueAST: Value) -> Map? {
        if let enumValue = valueAST as? EnumValue {
            return nameLookup[enumValue.value]?.value
        }
        return nil
    }

    public var description: String {
        return name
    }
}

func defineEnumValues(valueMap: GraphQLEnumValueConfigMap) throws -> [GraphQLEnumValueDefinition] {

    guard !valueMap.isEmpty else {
        return []
        //        invariant(
        //            valueNames.length > 0,
        //            `${type.name} values must be an object with value names as keys.`
        //        );
    }

    var definitions: [GraphQLEnumValueDefinition] = []

    for (valueName, value) in valueMap {
        try assertValid(name: valueName)

        let definition = GraphQLEnumValueDefinition(
            name: valueName,
            description: value.description,
            deprecationReason: value.deprecationReason,
            value: value.value
        )

        definitions.append(definition)
    }

    return definitions
}

public typealias GraphQLEnumValueConfigMap = [String: GraphQLEnumValueConfig]

public struct GraphQLEnumValueConfig {
    let value: Map
    let description: String?
    let deprecationReason: String?

    public init(value: Map, description: String? = nil, deprecationReason: String? = nil) {
        self.value = value
        self.description = description
        self.deprecationReason = deprecationReason
    }
}

struct GraphQLEnumValueDefinition {
    let name: String
    let description: String?
    let deprecationReason: String?
    let value: Map


    var isDeprecated: Bool {
        return deprecationReason != nil
    }
}

/**
 * Input Object Type Definition
 *
 * An input object defines a structured collection of fields which may be
 * supplied to a field argument.
 *
 * Using `NonNull` will ensure that a value must be provided by the query
 *
 * Example:
 *
 *     const GeoPoint = new GraphQLInputObjectType({
 *       name: 'GeoPoint',
 *       fields: {
 *         lat: { type: new GraphQLNonNull(GraphQLFloat) },
 *         lon: { type: new GraphQLNonNull(GraphQLFloat) },
 *         alt: { type: GraphQLFloat, defaultValue: 0 },
 *       }
 *     });
 *
 */
struct GraphQLInputObjectType {
    let name: String
    let inputObjectDescription: String?

    let fields: InputObjectFieldMap

    init(name: String, description: String? = nil, fields: InputObjectConfigFieldMap) throws {
        try assertValid(name: name)
        self.name = name
        self.inputObjectDescription = description
        self.fields = try defineInputObjectFieldMap(fields: fields)
    }

    var description: String {
        return name
    }
}

func defineInputObjectFieldMap(fields: InputObjectConfigFieldMap) throws -> InputObjectFieldMap {
    guard !fields.isEmpty else {
        return [:]
        //        invariant(
        //            fieldNames.length > 0,
        //            `${this.name} fields must be an object with field names as keys or a ` +
        //            'function which returns such an object.'
        //        );
    }

    var resultFieldMap = InputObjectFieldMap()

    for (fieldName, field) in fields {
        try assertValid(name: fieldName)

        let newField = InputObjectField(
            name: fieldName,
            description: field.description,
            type: field.type,
            defaultValue: field.defaultValue
        )

        resultFieldMap[fieldName] = newField
    }

    return resultFieldMap
}

struct InputObjectFieldConfig {
    let type: GraphQLInputType
    let defaultValue: Map?
    let description: String?
}

typealias InputObjectConfigFieldMap = [String: InputObjectFieldConfig]

struct InputObjectField {
    let name: String
    let description: String?
    let type: GraphQLInputType
    let defaultValue: Map?
}

typealias InputObjectFieldMap = [String: InputObjectField]

/**
 * List Modifier
 *
 * A list is a kind of type marker, a wrapping type which points to another
 * type. Lists are often created within the context of defining the fields of
 * an object type.
 *
 * Example:
 *
 *     const PersonType = new GraphQLObjectType({
 *       name: 'Person',
 *       fields: () => ({
 *         parents: { type: new GraphQLList(Person) },
 *         children: { type: new GraphQLList(Person) },
 *       })
 *     })
 *
 */
public struct GraphQLList : GraphQLType, GraphQLInputType, GraphQLWrapperType, GraphQLNullableType, GraphQLOutputType {
    let ofType: GraphQLType

    public init(_ type: GraphQLType) {
        self.ofType = type
    }

    var wrappedType: GraphQLType {
        return ofType
    }

    public var description: String {
        return "[" + ofType.description + "]"
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLList {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)
        return GraphQLList(resolvedType)
    }
}

/**
 * Non-Null Modifier
 *
 * A non-null is a kind of type marker, a wrapping type which points to another
 * type. Non-null types enforce that their values are never null and can ensure
 * an error is raised if this ever occurs during a request. It is useful for
 * fields which you can make a strong guarantee on non-nullability, for example
 * usually the id field of a database row will never be null.
 *
 * Example:
 *
 *     const RowType = new GraphQLObjectType({
 *       name: 'Row',
 *       fields: () => ({
 *         id: { type: new GraphQLNonNull(GraphQLString) },
 *       })
 *     })
 *
 * Note: the enforcement of non-nullability occurs within the executor.
 */
public struct GraphQLNonNull : GraphQLType, GraphQLInputType, GraphQLWrapperType, GraphQLOutputType {
    let ofType: GraphQLNullableType
    
    public init(_ type: GraphQLNullableType) {
        self.ofType = type
    }
    
    var wrappedType: GraphQLType {
        return ofType
    }
    
    public var description: String {
        return ofType.description + "!"
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLNonNull {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)

        guard let nullableType = resolvedType as? GraphQLNullableType else {
            throw GraphQLError(message: "Resolved type \"\(resolvedType)\" is not a valid nullable type.")
        }

        return GraphQLNonNull(nullableType)
    }
}

/**
 * A special type to allow a object/interface types to reference itself. It's replaced with the real type
 * object when the schema is build.
 */
public struct GraphQLTypeReference : GraphQLType, GraphQLOutputType, GraphQLNullableType {
    let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var description: String {
        return name
    }
}
