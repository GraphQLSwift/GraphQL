import NIO

/**
 * These are all of the possible kinds of types.
 */
public protocol GraphQLType      : CustomDebugStringConvertible, Encodable, KeySubscriptable {}
extension GraphQLScalarType      : GraphQLType                             {}
extension GraphQLObjectType      : GraphQLType                             {}
extension GraphQLInterfaceType   : GraphQLType                             {}
extension GraphQLUnionType       : GraphQLType                             {}
extension GraphQLEnumType        : GraphQLType                             {}
extension GraphQLInputObjectType : GraphQLType                             {}
extension GraphQLList            : GraphQLType                             {}
extension GraphQLNonNull         : GraphQLType                             {}

/**
 * These types may be used as input types for arguments and directives.
 */
public protocol GraphQLInputType : GraphQLType      {}
extension GraphQLScalarType      : GraphQLInputType {}
extension GraphQLEnumType        : GraphQLInputType {}
extension GraphQLInputObjectType : GraphQLInputType {}
extension GraphQLList            : GraphQLInputType {}
extension GraphQLNonNull         : GraphQLInputType {}
// TODO: Conditional conformances
//extension GraphQLList : GraphQLInputType where Element : GraphQLInputType {}
//extension GraphQLNonNull : GraphQLInputType where Element : (GraphQLScalarType | GraphQLEnumType | GraphQLInputObjectType | GraphQLList<GraphQLInputType>) {}

func isInputType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)
    return namedType is GraphQLInputType
}

/**
 * These types may be used as output types as the result of fields.
 */
public protocol GraphQLOutputType : GraphQLType       {}
extension GraphQLScalarType       : GraphQLOutputType {}
extension GraphQLObjectType       : GraphQLOutputType {}
extension GraphQLInterfaceType    : GraphQLOutputType {}
extension GraphQLUnionType        : GraphQLOutputType {}
extension GraphQLEnumType         : GraphQLOutputType {}
extension GraphQLList             : GraphQLOutputType {}
extension GraphQLNonNull          : GraphQLOutputType {}
// TODO: Conditional conformances
//extension GraphQLList : GraphQLOutputType where Element : GraphQLOutputType {}
//extension GraphQLNonNull : GraphQLInputType where Element : (GraphQLScalarType | GraphQLObjectType | GraphQLInterfaceType | GraphQLUnionType | GraphQLEnumType | GraphQLList<GraphQLOutputType>) {}

/**
 * These types may describe types which may be leaf values.
 */
public protocol GraphQLLeafType : GraphQLNamedType {
    func serialize(value: Any) throws -> Map
    func parseValue(value: Map) throws -> Map
    func parseLiteral(valueAST: Value) throws -> Map
}

extension GraphQLScalarType : GraphQLLeafType {}
extension GraphQLEnumType : GraphQLLeafType {}

func isLeafType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)
    return namedType is GraphQLScalarType ||
           namedType is GraphQLEnumType
}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLCompositeType : GraphQLNamedType, GraphQLOutputType {}
extension GraphQLObjectType          : GraphQLCompositeType                {}
extension GraphQLInterfaceType       : GraphQLCompositeType                {}
extension GraphQLUnionType           : GraphQLCompositeType                {}

protocol GraphQLTypeReferenceContainer : GraphQLNamedType {
    func replaceTypeReferences(typeMap: TypeMap) throws
}

extension GraphQLObjectType    : GraphQLTypeReferenceContainer {}
extension GraphQLInterfaceType : GraphQLTypeReferenceContainer {}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLAbstractType : GraphQLNamedType {
    var resolveType: GraphQLTypeResolve? { get }
}

extension GraphQLInterfaceType : GraphQLAbstractType {}
extension GraphQLUnionType     : GraphQLAbstractType {}

/**
 * These types can all accept null as a value.
 */
public protocol GraphQLNullableType : GraphQLType         {}
extension GraphQLScalarType         : GraphQLNullableType {}
extension GraphQLObjectType         : GraphQLNullableType {}
extension GraphQLInterfaceType      : GraphQLNullableType {}
extension GraphQLUnionType          : GraphQLNullableType {}
extension GraphQLEnumType           : GraphQLNullableType {}
extension GraphQLInputObjectType    : GraphQLNullableType {}
extension GraphQLList               : GraphQLNullableType {}

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

extension GraphQLScalarType      : GraphQLNamedType {}
extension GraphQLObjectType      : GraphQLNamedType {}
extension GraphQLInterfaceType   : GraphQLNamedType {}
extension GraphQLUnionType       : GraphQLNamedType {}
extension GraphQLEnumType        : GraphQLNamedType {}
extension GraphQLInputObjectType : GraphQLNamedType {}

public func getNamedType(type: GraphQLType?) -> GraphQLNamedType? {
    var unmodifiedType = type

    while let type = unmodifiedType as? GraphQLWrapperType {
        unmodifiedType = type.wrappedType
    }

    return unmodifiedType as? GraphQLNamedType
}

/**
 * These types wrap other types.
 */
protocol GraphQLWrapperType : GraphQLType {
    var wrappedType: GraphQLType { get }
}

extension GraphQLList    : GraphQLWrapperType {}
extension GraphQLNonNull : GraphQLWrapperType {}

/**
 * Scalar Type Definition
 *
 * The leaf values of any request and input values to arguments are
 * Scalars (or Enums) and are defined with a name and a series of functions
 * used to parse input from ast or variables and to ensure validity.
 *
 * Example:
 *
 *     let oddType = try ScalarType(
 *         name: "Bool",
 *         serialize: {
 *             try $0.map.asBool(converting: true)
 *         }
 *     )
 *
 */
public final class GraphQLScalarType {
    public let name: String
    public let description: String?
    public let kind: TypeKind = .scalar
    
    let serialize: (Any) throws -> Map
    let parseValue: ((Map) throws -> Map)?
    let parseLiteral: ((Value) throws -> Map)?

    public init(
        name: String,
        description: String? = nil,
        serialize: @escaping (Any) throws -> Map
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.serialize = serialize
        self.parseValue = nil
        self.parseLiteral = nil
    }

    public init(
        name: String,
        description: String? = nil,
        serialize: @escaping (Any) throws -> Map,
        parseValue: @escaping (Map) throws -> Map,
        parseLiteral: @escaping (Value) throws -> Map
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.serialize = serialize
        self.parseValue = parseValue
        self.parseLiteral = parseLiteral
    }

    // Serializes an internal value to include in a response.
    public func serialize(value: Any) throws -> Map {
        return try self.serialize(value)
    }

    // Parses an externally provided value to use as an input.
    public func parseValue(value: Map) throws -> Map {
        return try self.parseValue?(value) ?? Map.null
    }

    // Parses an externally provided literal value to use as an input.
    public func parseLiteral(valueAST: Value) throws -> Map {
        return try self.parseLiteral?(valueAST) ?? Map.null
    }
}

extension GraphQLScalarType  : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case kind
    }
}

extension GraphQLScalarType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLScalarType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLScalarType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLScalarType, rhs: GraphQLScalarType) -> Bool {
        return lhs.hashValue == rhs.hashValue
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
 *     let AddressType = GraphQLObjectType(
 *         name: "Address",
 *         fields: [
 *             "street": GraphQLField(type: GraphQLString),
 *             "number": GraphQLField(type: GraphQLInt),
 *             "formatted": GraphQLField(
 *                 type: GraphQLString,
 *                 resolve: { address, _, _, _ in
 *                     guard let address = address as? Address {
 *                         return Map.null
 *                     }
 *
 *                     return "\(address.number) \(address.street)"
 *                 }
 *             )
 *         ]
 *     )
 *
 * When two types need to refer to each other, or a type needs to refer to
 * itself in a field, you can wrap it in a GraphQLTypeReference to supply the fields lazily.
 *
 * Example:
 *
 *     let PersonType = GraphQLObjectType(
 *         name: "Person",
 *         fields: [
 *             "name": GraphQLField(type: GraphQLString),
 *             "bestFriend": GraphQLField(type: GraphQLTypeReference("PersonType")),
 *         ]
 *     )
 *
 */
public final class GraphQLObjectType {
    public let name: String
    public let description: String?
    public let fields: GraphQLFieldDefinitionMap
    public let interfaces: [GraphQLInterfaceType]
    public let isTypeOf: GraphQLIsTypeOf?
    public let kind: TypeKind = .object
    
    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap,
        interfaces: [GraphQLInterfaceType] = [],
        isTypeOf: GraphQLIsTypeOf? = nil
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = try defineFieldMap(
            name: name,
            fields: fields
        )
        self.interfaces = try defineInterfaces(
            name: name,
            hasTypeOf: isTypeOf != nil,
            interfaces: interfaces
        )
        self.isTypeOf = isTypeOf
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLObjectType : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case fields
        case interfaces
        case kind
    }
}

extension GraphQLObjectType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.fields.rawValue:
            return self.fields
        case CodingKeys.interfaces.rawValue:
            return self.interfaces
        case CodingKeys.kind.rawValue:
            return self.kind.rawValue
        default:
            return nil
        }
    }
}

extension GraphQLObjectType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLObjectType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLObjectType, rhs: GraphQLObjectType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

func defineFieldMap(name: String, fields: GraphQLFieldMap) throws -> GraphQLFieldDefinitionMap {
    guard !fields.isEmpty else {
        throw GraphQLError(
            message:
            "\(name) fields must be an object with field names as " +
            "keys or a function which returns such an object."
        )
    }

    var fieldMap = GraphQLFieldDefinitionMap()

    for (name, config) in fields {
        try assertValid(name: name)

        let field = GraphQLFieldDefinition(
            name: name,
            type: config.type,
            description: config.description,
            deprecationReason: config.deprecationReason,
            args: try defineArgumentMap(args: config.args),
            resolve: config.resolve
        )

        fieldMap[name] = field
    }

    return fieldMap
}

func defineArgumentMap(args: GraphQLArgumentConfigMap) throws -> [GraphQLArgumentDefinition] {
    var arguments: [GraphQLArgumentDefinition] = []

    for (name, config) in args {
        try assertValid(name: name)
        let argument = GraphQLArgumentDefinition(
            name: name,
            type: config.type,
            defaultValue: config.defaultValue,
            description: config.description
        )
        arguments.append(argument)
    }

    return arguments
}

func defineInterfaces(
    name: String,
    hasTypeOf: Bool,
    interfaces: [GraphQLInterfaceType]
) throws -> [GraphQLInterfaceType] {
    guard !interfaces.isEmpty else {
        return []
    }

    if !hasTypeOf {
        for interface in interfaces {
            guard interface.resolveType != nil else {
                throw GraphQLError(
                    message:
                    "Interface Type \(interface.name) does not provide a \"resolveType\" " +
                    "function and implementing Type \(name) does not provide a " +
                    "\"isTypeOf\" function. There is no way to resolve this implementing " +
                    "type during execution."
                )
            }
        }
    }

    return interfaces
}

public protocol TypeResolveResultRepresentable {
    var typeResolveResult: TypeResolveResult { get }
}

extension GraphQLObjectType : TypeResolveResultRepresentable {
    public var typeResolveResult: TypeResolveResult {
        return .type(self)
    }
}

extension String : TypeResolveResultRepresentable {
    public var typeResolveResult: TypeResolveResult {
        return .name(self)
    }
}

public enum TypeResolveResult {
    case type(GraphQLObjectType)
    case name(String)
}

public typealias GraphQLTypeResolve = (
    _ value: Any,
    _ eventLoopGroup: EventLoopGroup,
    _ info: GraphQLResolveInfo
) throws -> TypeResolveResultRepresentable

public typealias GraphQLIsTypeOf = (
    _ source: Any,
    _ eventLoopGroup: EventLoopGroup,
    _ info: GraphQLResolveInfo
) throws -> Bool

public typealias GraphQLFieldResolve = (
    _ source: Any,
    _ args: Map,
    _ context: Any,
    _ eventLoopGroup: EventLoopGroup,
    _ info: GraphQLResolveInfo
) throws -> Future<Any?>

public typealias GraphQLFieldResolveInput = (
    _ source: Any,
    _ args: Map,
    _ context: Any,
    _ info: GraphQLResolveInfo
) throws -> Any?

public struct GraphQLResolveInfo {
    public let fieldName: String
    public let fieldASTs: [Field]
    public let returnType: GraphQLOutputType
    public let parentType: GraphQLCompositeType
    public let path: IndexPath
    public let schema: GraphQLSchema
    public let fragments: [String: FragmentDefinition]
    public let rootValue: Any
    public let operation: OperationDefinition
    public let variableValues: [String: Any]
}

public typealias GraphQLFieldMap = [String: GraphQLField]

public struct GraphQLField {
    public let type: GraphQLOutputType
    public let args: GraphQLArgumentConfigMap
    public let deprecationReason: String?
    public let description: String?
    public let resolve: GraphQLFieldResolve?
    
    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:]
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.resolve = nil
    }
    
    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        resolve: GraphQLFieldResolve?
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.resolve = resolve
    }
    
    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        resolve: @escaping GraphQLFieldResolveInput
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        
        self.resolve = { source, args, context, eventLoopGroup, info in
            let result = try resolve(source, args, context, info)
            return eventLoopGroup.next().makeSucceededFuture(result)
        }
    }
}

public typealias GraphQLFieldDefinitionMap = [String: GraphQLFieldDefinition]

public final class GraphQLFieldDefinition {
    public let name: String
    public let description: String?
    public internal(set) var type: GraphQLOutputType
    public let args: [GraphQLArgumentDefinition]
    public let resolve: GraphQLFieldResolve?
    public let deprecationReason: String?
    public let isDeprecated: Bool

    init(
        name: String,
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: [GraphQLArgumentDefinition] = [],
        resolve: GraphQLFieldResolve?
    ) {
        self.name = name
        self.description = description
        self.type = type
        self.args = args
        self.resolve = resolve
        self.deprecationReason = deprecationReason
        self.isDeprecated = deprecationReason != nil
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        let resolvedType = try resolveTypeReference(type: type, typeMap: typeMap)

        guard let outputType = resolvedType as? GraphQLOutputType else {
            throw GraphQLError(
                message: "Resolved type \"\(resolvedType)\" is not a valid output type."
            )
        }

        self.type = outputType
    }
}

extension GraphQLFieldDefinition : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case type
        case args
        case deprecationReason
        case isDeprecated
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.description, forKey: .description)
        try container.encode(AnyEncodable(self.type), forKey: .type)
        try container.encode(self.args, forKey: .args)
        try container.encode(self.deprecationReason, forKey: .deprecationReason)
        try container.encode(self.isDeprecated, forKey: .isDeprecated)
    }
}

extension GraphQLFieldDefinition : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.type.rawValue:
            return self.type
        case CodingKeys.args.rawValue:
            return self.args
        case CodingKeys.deprecationReason.rawValue:
            return self.deprecationReason
        case CodingKeys.isDeprecated.rawValue:
            return self.isDeprecated
        default:
            return nil
        }
    }
}

public typealias GraphQLArgumentConfigMap = [String: GraphQLArgument]

public struct GraphQLArgument {
    public let type: GraphQLInputType
    public let description: String?
    public let defaultValue: Map?

    public init(
        type: GraphQLInputType,
        description: String? = nil,
        defaultValue: Map? = nil
    ) {
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
    }
}

public struct GraphQLArgumentDefinition {
    public let name: String
    public let type: GraphQLInputType
    public let defaultValue: Map?
    public let description: String?

    init(
        name: String,
        type: GraphQLInputType,
        defaultValue: Map? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
    }
}

extension GraphQLArgumentDefinition : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case type
        case defaultValue
    }
 
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.description, forKey: .description)
        try container.encode(AnyEncodable(self.type), forKey: .type)
        try container.encode(self.defaultValue, forKey: .defaultValue)
    }
}

extension GraphQLArgumentDefinition : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.type.rawValue:
            return self.type
        case CodingKeys.defaultValue.rawValue:
            return self.defaultValue
        default:
            return nil
        }
    }
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
 *     let EntityType = GraphQLInterfaceType(
 *         name: "Entity",
 *         fields: {
 *             "name": GraphQLField(type: GraphQLString)
 *         }
 *     )
 *
 */
public final class GraphQLInterfaceType {
    public let name: String
    public let description: String?
    public let resolveType: GraphQLTypeResolve?
    public let fields: GraphQLFieldDefinitionMap
    public let kind: TypeKind = .interface

    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap,
        resolveType: GraphQLTypeResolve? = nil
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = try defineFieldMap(
            name: name,
            fields: fields
        )
        self.resolveType = resolveType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLInterfaceType : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case fields
        case kind
    }
}

extension GraphQLInterfaceType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.fields.rawValue:
            return self.fields
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLInterfaceType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLInterfaceType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLInterfaceType, rhs: GraphQLInterfaceType) -> Bool {
        return lhs.hashValue == rhs.hashValue
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
 *     let PetType = try GraphQLUnionType(
 *         name: "Pet",
 *         types: [DogType, CatType],
 *         resolveType: { value, context, info in
 *             switch value {
 *             case is Dog:
 *                 return DogType
 *             case is Cat:
 *                 return CatType
 *             default:
 *                 return Map.null
 *             }
 *         }
 *     )
 *
 */
public final class GraphQLUnionType {
    public let name: String
    public let description: String?
    public let resolveType: GraphQLTypeResolve?
    public let types: [GraphQLObjectType]
    public let possibleTypeNames: [String: Bool]
    public let kind: TypeKind = .union

    public init(
        name: String,
        description: String? = nil,
        resolveType: GraphQLTypeResolve? = nil,
        types: [GraphQLObjectType]
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.resolveType = resolveType
        
        self.types = try defineTypes(
            name: name,
            hasResolve: resolveType != nil,
            types: types
        )
        
        self.possibleTypeNames = [:]
    }
}

extension GraphQLUnionType : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case types
        case kind
    }
}

extension GraphQLUnionType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.types.rawValue:
            return self.types
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLUnionType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLUnionType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLUnionType, rhs: GraphQLUnionType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

func defineTypes(
    name: String,
    hasResolve: Bool,
    types: [GraphQLObjectType]
) throws -> [GraphQLObjectType] {
    guard !types.isEmpty else {
        throw GraphQLError(
            message:
            "Must provide Array of types or a function which returns " +
            "such an array for Union \(name)."
        )
    }

    if !hasResolve {
        for type in types {
            guard type.isTypeOf != nil else {
                throw GraphQLError(
                    message:
                    "Union type \"\(name)\" does not provide a \"resolveType\" " +
                    "function and possible type \"\(type.name)\" does not provide an " +
                    "\"isTypeOf\" function. There is no way to resolve this possible type " +
                    "during execution."
                )
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
 *     let RGBType = GraphQLEnumType(
 *         name: "RGB",
 *         values: {
 *             "RED": GraphQLEnumValue(value: 0),
 *             "GREEN": GraphQLEnumValue(value: 1),
 *             "BLUE": GraphQLEnumValue(value: 2)
 *       }
 *     )
 *
 * Note: If a value is not provided in a definition, the name of the enum value
 * will be used as its internal value.
 */
public final class GraphQLEnumType {
    public let name: String
    public let description: String?
    public let values: [GraphQLEnumValueDefinition]
    public let valueLookup: [Map: GraphQLEnumValueDefinition]
    public let nameLookup: [String: GraphQLEnumValueDefinition]
    public let kind: TypeKind = .enum

    public init(
        name: String,
        description: String? = nil,
        values: GraphQLEnumValueMap
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.values = try defineEnumValues(
            name: name,
            valueMap: values
        )

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

    public func serialize(value: Any) throws -> Map {
        return try valueLookup[map(from: value)].map({ .string($0.name) }) ?? .null
    }

    public func parseValue(value: Map) throws -> Map {
        if case .string(let value) = value {
            return nameLookup[value]?.value ?? .null
        }

        return .null
    }

    public func parseLiteral(valueAST: Value) -> Map {
        if let enumValue = valueAST as? EnumValue {
            return nameLookup[enumValue.value]?.value ?? .null
        }

        return .null
    }
}

extension GraphQLEnumType : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case values
        case kind
    }
}

extension GraphQLEnumType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.values.rawValue:
            return self.values
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLEnumType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLEnumType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLEnumType, rhs: GraphQLEnumType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

func defineEnumValues(
    name: String,
    valueMap: GraphQLEnumValueMap
) throws -> [GraphQLEnumValueDefinition] {
    guard !valueMap.isEmpty else {
        throw GraphQLError(
            message: "\(name) values must be an object with value names as keys."
        )
    }

    var definitions: [GraphQLEnumValueDefinition] = []

    for (valueName, value) in valueMap {
        try assertValid(name: valueName)

        let definition = GraphQLEnumValueDefinition(
            name: valueName,
            description: value.description,
            deprecationReason: value.deprecationReason,
            isDeprecated: value.deprecationReason != nil,
            value: value.value
        )

        definitions.append(definition)
    }

    return definitions
}

public typealias GraphQLEnumValueMap = [String: GraphQLEnumValue]

public struct GraphQLEnumValue {
    public let value: Map
    public let description: String?
    public let deprecationReason: String?

    public init(
        value: Map,
        description: String? = nil,
        deprecationReason: String? = nil
    ) {
        self.value = value
        self.description = description
        self.deprecationReason = deprecationReason
    }
}

public struct GraphQLEnumValueDefinition : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case deprecationReason
        case isDeprecated
    }
    
    public let name: String
    public let description: String?
    public let deprecationReason: String?
    public let isDeprecated: Bool
    public let value: Map
}

extension GraphQLEnumValueDefinition : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.deprecationReason.rawValue:
            return self.deprecationReason
        case CodingKeys.isDeprecated.rawValue:
            return self.isDeprecated
        default:
            return nil
        }
    }
}

/**
 * Input Object Type Definition
 *
 * An input object defines a structured collection of fields which may be
 * supplied to a field argument.
 *
 * Using `GraphQLNonNull` will ensure that a value must be provided by the query
 *
 * Example:
 *
 *     let GeoPoint = GraphQLInputObjectType(
 *         name: "GeoPoint",
 *         fields: [
 *             "lat": InputObjectField(type: GraphQLNonNull(GraphQLFloat)),
 *             "lon": InputObjectField(type: GraphQLNonNull(GraphQLFloat)),
 *             "alt": InputObjectField(type: GraphQLFloat, defaultValue: 0),
 *         ]
 *     )
 *
 */
public final class GraphQLInputObjectType {
    public let name: String
    public let description: String?
    public let fields: InputObjectFieldMap
    public let kind: TypeKind = .inputObject

    public init(
        name: String,
        description: String? = nil,
        fields: InputObjectConfigFieldMap
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = try defineInputObjectFieldMap(
            name: name,
            fields: fields
        )
    }
}

extension GraphQLInputObjectType : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case fields
        case kind
    }
}

extension GraphQLInputObjectType : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.fields.rawValue:
            return self.fields
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLInputObjectType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLInputObjectType : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLInputObjectType, rhs: GraphQLInputObjectType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

func defineInputObjectFieldMap(
    name: String,
    fields: InputObjectConfigFieldMap
) throws -> InputObjectFieldMap {
    guard !fields.isEmpty else {
        throw GraphQLError(
            message:
            "\(name) fields must be an object with field names as keys or a " +
            "function which returns such an object."
        )
    }

    var resultFieldMap = InputObjectFieldMap()

    for (fieldName, field) in fields {
        try assertValid(name: fieldName)

        let newField = InputObjectFieldDefinition(
            name: fieldName,
            description: field.description,
            type: field.type,
            defaultValue: field.defaultValue
        )

        resultFieldMap[fieldName] = newField
    }

    return resultFieldMap
}

public struct InputObjectField {
    public let type: GraphQLInputType
    public let defaultValue: Map?
    public let description: String?
    
    public init(type: GraphQLInputType, defaultValue: Map? = nil, description: String? = nil) {
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
    }
}

public typealias InputObjectConfigFieldMap = [String: InputObjectField]

public struct InputObjectFieldDefinition {
    public let name: String
    public let description: String?
    public let type: GraphQLInputType
    public let defaultValue: Map?
}

extension InputObjectFieldDefinition : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
        case description
        case type
        case defaultValue
    }
 
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.description, forKey: .description)
        try container.encode(AnyEncodable(self.type), forKey: .type)
        try container.encode(self.defaultValue, forKey: .defaultValue)
    }
}

extension InputObjectFieldDefinition : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return self.name
        case CodingKeys.description.rawValue:
            return self.description
        case CodingKeys.type.rawValue:
            return self.type
        case CodingKeys.defaultValue.rawValue:
            return self.defaultValue
        default:
            return nil
        }
    }
}

public typealias InputObjectFieldMap = [String: InputObjectFieldDefinition]

/**
 * List Modifier
 *
 * A list is a kind of type marker, a wrapping type which points to another
 * type. Lists are often created within the context of defining the fields of
 * an object type.
 *
 * Example:
 *
 *     let PersonType = GraphQLObjectType(
 *         name: "Person",
 *         fields: [
 *             "parents": GraphQLField(type: GraphQLList("Person")),
 *             "children": GraphQLField(type: GraphQLList("Person")),
 *         ]
 *     )
 *
 */
public final class GraphQLList {
    public let ofType: GraphQLType
    public let kind: TypeKind = .list

    public init(_ type: GraphQLType) {
        self.ofType = type
    }

    public init(_ name: String) {
        self.ofType = GraphQLTypeReference(name)
    }

    var wrappedType: GraphQLType {
        return ofType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLList {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)
        return GraphQLList(resolvedType)
    }
}

extension GraphQLList : Encodable {
    private enum CodingKeys : String, CodingKey {
        case ofType
        case kind
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AnyEncodable(self.ofType), forKey: .ofType)
        try container.encode(self.kind, forKey: .kind)
    }
}

extension GraphQLList : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.ofType.rawValue:
            return self.ofType
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLList : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[" + ofType.debugDescription + "]"
    }
}

extension GraphQLList : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLList, rhs: GraphQLList) -> Bool {
        return lhs.hashValue == rhs.hashValue
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
 *     let RowType = GraphQLObjectType(
 *         name: "Row",
 *         fields: [
 *             "id": GraphQLField(type: GraphQLNonNull(GraphQLString)),
 *         ]
 *     )
 *
 * Note: the enforcement of non-nullability occurs within the executor.
 */
public final class GraphQLNonNull {
    public let ofType: GraphQLNullableType
    public let kind: TypeKind = .nonNull

    public init(_ type: GraphQLNullableType) {
        self.ofType = type
    }

    public init(_ name: String) {
        self.ofType = GraphQLTypeReference(name)
    }

    var wrappedType: GraphQLType {
        return ofType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLNonNull {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)

        guard let nullableType = resolvedType as? GraphQLNullableType else {
            throw GraphQLError(
                message: "Resolved type \"\(resolvedType)\" is not a valid nullable type."
            )
        }

        return GraphQLNonNull(nullableType)
    }
}

extension GraphQLNonNull : Encodable {
    private enum CodingKeys : String, CodingKey {
        case ofType
        case kind
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AnyEncodable(self.ofType), forKey: .ofType)
        try container.encode(self.kind, forKey: .kind)
    }
}

extension GraphQLNonNull : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.ofType.rawValue:
            return self.ofType
        case CodingKeys.kind.rawValue:
            return self.kind
        default:
            return nil
        }
    }
}

extension GraphQLNonNull : CustomDebugStringConvertible {
    public var debugDescription: String {
        return ofType.debugDescription + "!"
    }
}

extension GraphQLNonNull : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLNonNull, rhs: GraphQLNonNull) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

/**
 * A special type to allow a object/interface types to reference itself. It's replaced with the real type
 * object when the schema is built.
 */
public final class GraphQLTypeReference : GraphQLType, GraphQLOutputType, GraphQLNullableType {
    public let name: String
    public let kind: TypeKind = .typeReference

    public init(_ name: String) {
        self.name = name
    }
}

extension GraphQLTypeReference : Encodable {
    private enum CodingKeys : String, CodingKey {
        case name
    }
}

extension GraphQLTypeReference : KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch name {
        case CodingKeys.name.rawValue:
            return self.name
        default:
            return nil
        }
    }
}

extension GraphQLTypeReference : CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}
