import Foundation
import NIO
import OrderedCollections

/**
 * These are all of the possible kinds of types.
 */
public protocol GraphQLType: CustomDebugStringConvertible, Encodable, KeySubscriptable {}
extension GraphQLScalarType: GraphQLType {}
extension GraphQLObjectType: GraphQLType {}
extension GraphQLInterfaceType: GraphQLType {}
extension GraphQLUnionType: GraphQLType {}
extension GraphQLEnumType: GraphQLType {}
extension GraphQLInputObjectType: GraphQLType {}
extension GraphQLList: GraphQLType {}
extension GraphQLNonNull: GraphQLType {}

/**
 * These types may be used as input types for arguments and directives.
 */
public protocol GraphQLInputType: GraphQLType {}
extension GraphQLScalarType: GraphQLInputType {}
extension GraphQLEnumType: GraphQLInputType {}
extension GraphQLInputObjectType: GraphQLInputType {}
extension GraphQLList: GraphQLInputType {}
extension GraphQLNonNull: GraphQLInputType {}
// TODO: Conditional conformances
// extension GraphQLList : GraphQLInputType where Element : GraphQLInputType {}
// extension GraphQLNonNull : GraphQLInputType where Element : (GraphQLScalarType | GraphQLEnumType
// | GraphQLInputObjectType | GraphQLList<GraphQLInputType>) {}

func isInputType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)
    return namedType is GraphQLInputType
}

/**
 * These types may be used as output types as the result of fields.
 */
public protocol GraphQLOutputType: GraphQLType {}
extension GraphQLScalarType: GraphQLOutputType {}
extension GraphQLObjectType: GraphQLOutputType {}
extension GraphQLInterfaceType: GraphQLOutputType {}
extension GraphQLUnionType: GraphQLOutputType {}
extension GraphQLEnumType: GraphQLOutputType {}
extension GraphQLList: GraphQLOutputType {}
extension GraphQLNonNull: GraphQLOutputType {}
// TODO: Conditional conformances
// extension GraphQLList : GraphQLOutputType where Element : GraphQLOutputType {}
// extension GraphQLNonNull : GraphQLInputType where Element : (GraphQLScalarType |
// GraphQLObjectType | GraphQLInterfaceType | GraphQLUnionType | GraphQLEnumType |
// GraphQLList<GraphQLOutputType>) {}

/**
 * These types may describe types which may be leaf values.
 */
public protocol GraphQLLeafType: GraphQLNamedType {
    func serialize(value: Any) throws -> Map
    func parseValue(value: Map) throws -> Map
    func parseLiteral(valueAST: Value) throws -> Map
}

extension GraphQLScalarType: GraphQLLeafType {}
extension GraphQLEnumType: GraphQLLeafType {}

func isLeafType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)
    return namedType is GraphQLScalarType ||
        namedType is GraphQLEnumType
}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLCompositeType: GraphQLNamedType, GraphQLOutputType {}
extension GraphQLObjectType: GraphQLCompositeType {}
extension GraphQLInterfaceType: GraphQLCompositeType {}
extension GraphQLUnionType: GraphQLCompositeType {}

protocol GraphQLTypeReferenceContainer: GraphQLNamedType {
    func replaceTypeReferences(typeMap: TypeMap) throws
}

extension GraphQLObjectType: GraphQLTypeReferenceContainer {}
extension GraphQLInterfaceType: GraphQLTypeReferenceContainer {}
extension GraphQLInputObjectType: GraphQLTypeReferenceContainer {}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLAbstractType: GraphQLNamedType {
    var resolveType: GraphQLTypeResolve? { get }
}

extension GraphQLInterfaceType: GraphQLAbstractType {}
extension GraphQLUnionType: GraphQLAbstractType {}

/**
 * These types can all accept null as a value.
 */
public protocol GraphQLNullableType: GraphQLType {}
extension GraphQLScalarType: GraphQLNullableType {}
extension GraphQLObjectType: GraphQLNullableType {}
extension GraphQLInterfaceType: GraphQLNullableType {}
extension GraphQLUnionType: GraphQLNullableType {}
extension GraphQLEnumType: GraphQLNullableType {}
extension GraphQLInputObjectType: GraphQLNullableType {}
extension GraphQLList: GraphQLNullableType {}

func getNullableType(type: GraphQLType?) -> GraphQLNullableType? {
    if let type = type as? GraphQLNonNull {
        return type.ofType
    }

    return type as? GraphQLNullableType
}

/**
 * These named types do not include modifiers like List or NonNull.
 */
public protocol GraphQLNamedType: GraphQLNullableType {
    var name: String { get }
}

extension GraphQLScalarType: GraphQLNamedType {}
extension GraphQLObjectType: GraphQLNamedType {}
extension GraphQLInterfaceType: GraphQLNamedType {}
extension GraphQLUnionType: GraphQLNamedType {}
extension GraphQLEnumType: GraphQLNamedType {}
extension GraphQLInputObjectType: GraphQLNamedType {}

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
protocol GraphQLWrapperType: GraphQLType {
    var wrappedType: GraphQLType { get }
}

extension GraphQLList: GraphQLWrapperType {}
extension GraphQLNonNull: GraphQLWrapperType {}

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
    public let specifiedByURL: String?
    public let astNode: ScalarTypeDefinition?
    public let extensionASTNodes: [ScalarExtensionDefinition]
    public let kind: TypeKind = .scalar

    let serialize: (Any) throws -> Map
    let parseValue: (Map) throws -> Map
    let parseLiteral: (Value) throws -> Map

    public init(
        name: String,
        description: String? = nil,
        specifiedByURL: String? = nil,
        serialize: @escaping (Any) throws -> Map = { try map(from: $0) },
        parseValue: ((Map) throws -> Map)? = nil,
        parseLiteral: ((Value) throws -> Map)? = nil,
        astNode: ScalarTypeDefinition? = nil,
        extensionASTNodes: [ScalarExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.specifiedByURL = specifiedByURL
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
        self.serialize = serialize
        self.parseValue = parseValue ?? defaultParseValue
        self.parseLiteral = parseLiteral ?? defaultParseLiteral
    }

    // Serializes an internal value to include in a response.
    public func serialize(value: Any) throws -> Map {
        return try serialize(value)
    }

    // Parses an externally provided value to use as an input.
    public func parseValue(value: Map) throws -> Map {
        return try parseValue(value)
    }

    // Parses an externally provided literal value to use as an input.
    public func parseLiteral(valueAST: Value) throws -> Map {
        return try parseLiteral(valueAST)
    }
}

let defaultParseValue: ((Map) throws -> Map) = { value in
    value
}

let defaultParseLiteral: ((Value) throws -> Map) = { value in
    try valueFromASTUntyped(valueAST: value)
}

extension GraphQLScalarType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case specifiedByURL
        case kind
    }
}

extension GraphQLScalarType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.specifiedByURL.rawValue:
            return specifiedByURL
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLScalarType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLScalarType: Hashable {
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
    public let astNode: ObjectTypeDefinition?
    public let extensionASTNodes: [TypeExtensionDefinition]
    public let kind: TypeKind = .object

    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap,
        interfaces: [GraphQLInterfaceType] = [],
        isTypeOf: GraphQLIsTypeOf? = nil,
        astNode: ObjectTypeDefinition? = nil,
        extensionASTNodes: [TypeExtensionDefinition] = []
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
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLObjectType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case fields
        case interfaces
        case kind
    }
}

extension GraphQLObjectType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.fields.rawValue:
            return fields
        case CodingKeys.interfaces.rawValue:
            return interfaces
        case CodingKeys.kind.rawValue:
            return kind.rawValue
        default:
            return nil
        }
    }
}

extension GraphQLObjectType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLObjectType: Hashable {
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

        let field = try GraphQLFieldDefinition(
            name: name,
            type: config.type,
            description: config.description,
            deprecationReason: config.deprecationReason,
            args: defineArgumentMap(args: config.args),
            resolve: config.resolve,
            subscribe: config.subscribe,
            astNode: config.astNode
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
            description: config.description,
            deprecationReason: config.deprecationReason,
            astNode: config.astNode
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

extension GraphQLObjectType: TypeResolveResultRepresentable {
    public var typeResolveResult: TypeResolveResult {
        return .type(self)
    }
}

extension String: TypeResolveResultRepresentable {
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

public typealias GraphQLFieldMap = OrderedDictionary<String, GraphQLField>

public struct GraphQLField {
    public let type: GraphQLOutputType
    public let args: GraphQLArgumentConfigMap
    public let deprecationReason: String?
    public let description: String?
    public let resolve: GraphQLFieldResolve?
    public let subscribe: GraphQLFieldResolve?
    public let astNode: FieldDefinition?

    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        astNode: FieldDefinition? = nil
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.astNode = astNode
        resolve = nil
        subscribe = nil
    }

    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        resolve: GraphQLFieldResolve?,
        subscribe: GraphQLFieldResolve? = nil,
        astNode: FieldDefinition? = nil
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.astNode = astNode
        self.resolve = resolve
        self.subscribe = subscribe
    }

    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        astNode: FieldDefinition? = nil,
        resolve: @escaping GraphQLFieldResolveInput
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.astNode = astNode

        self.resolve = { source, args, context, eventLoopGroup, info in
            let result = try resolve(source, args, context, info)
            return eventLoopGroup.next().makeSucceededFuture(result)
        }
        subscribe = nil
    }
}

public typealias GraphQLFieldDefinitionMap = OrderedDictionary<String, GraphQLFieldDefinition>

public final class GraphQLFieldDefinition {
    public let name: String
    public let description: String?
    public internal(set) var type: GraphQLOutputType
    public let args: [GraphQLArgumentDefinition]
    public let resolve: GraphQLFieldResolve?
    public let subscribe: GraphQLFieldResolve?
    public let deprecationReason: String?
    public let isDeprecated: Bool
    public let astNode: FieldDefinition?

    init(
        name: String,
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: [GraphQLArgumentDefinition] = [],
        resolve: GraphQLFieldResolve?,
        subscribe: GraphQLFieldResolve? = nil,
        astNode: FieldDefinition? = nil
    ) {
        self.name = name
        self.description = description
        self.type = type
        self.args = args
        self.resolve = resolve
        self.subscribe = subscribe
        self.deprecationReason = deprecationReason
        isDeprecated = deprecationReason != nil
        self.astNode = astNode
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        let resolvedType = try resolveTypeReference(type: type, typeMap: typeMap)

        guard let outputType = resolvedType as? GraphQLOutputType else {
            throw GraphQLError(
                message: "Resolved type \"\(resolvedType)\" is not a valid output type."
            )
        }

        type = outputType
    }

    func toField() -> GraphQLField {
        return .init(
            type: type,
            description: description,
            deprecationReason: deprecationReason,
            args: argConfigMap(),
            resolve: resolve,
            subscribe: subscribe,
            astNode: astNode
        )
    }

    func argConfigMap() -> GraphQLArgumentConfigMap {
        var argConfigs: GraphQLArgumentConfigMap = [:]
        for argDef in args {
            argConfigs[argDef.name] = argDef.toArg()
        }
        return argConfigs
    }
}

extension GraphQLFieldDefinition: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case args
        case deprecationReason
        case isDeprecated
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(AnyEncodable(type), forKey: .type)
        try container.encode(args, forKey: .args)
        try container.encode(deprecationReason, forKey: .deprecationReason)
        try container.encode(isDeprecated, forKey: .isDeprecated)
    }
}

extension GraphQLFieldDefinition: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.type.rawValue:
            return type
        case CodingKeys.args.rawValue:
            return args
        case CodingKeys.deprecationReason.rawValue:
            return deprecationReason
        case CodingKeys.isDeprecated.rawValue:
            return isDeprecated
        default:
            return nil
        }
    }
}

public typealias GraphQLArgumentConfigMap = OrderedDictionary<String, GraphQLArgument>

public struct GraphQLArgument {
    public let type: GraphQLInputType
    public let description: String?
    public let defaultValue: Map?
    public let deprecationReason: String?
    public let astNode: InputValueDefinition?

    public init(
        type: GraphQLInputType,
        description: String? = nil,
        defaultValue: Map? = nil,
        deprecationReason: String? = nil,
        astNode: InputValueDefinition? = nil
    ) {
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
        self.deprecationReason = deprecationReason
        self.astNode = astNode
    }
}

public struct GraphQLArgumentDefinition {
    public let name: String
    public let type: GraphQLInputType
    public let defaultValue: Map?
    public let description: String?
    public let deprecationReason: String?
    public let astNode: InputValueDefinition?

    init(
        name: String,
        type: GraphQLInputType,
        defaultValue: Map? = nil,
        description: String? = nil,
        deprecationReason: String? = nil,
        astNode: InputValueDefinition? = nil
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.deprecationReason = deprecationReason
        self.astNode = astNode
    }

    func toArg() -> GraphQLArgument {
        return .init(
            type: type,
            description: description,
            defaultValue: defaultValue,
            deprecationReason: deprecationReason,
            astNode: astNode
        )
    }
}

public func isRequiredArgument(_ arg: GraphQLArgumentDefinition) -> Bool {
    return arg.type is GraphQLNonNull && arg.defaultValue == nil
}

extension GraphQLArgumentDefinition: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case defaultValue
        case deprecationReason
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(AnyEncodable(type), forKey: .type)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(deprecationReason, forKey: .deprecationReason)
    }
}

extension GraphQLArgumentDefinition: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.type.rawValue:
            return type
        case CodingKeys.defaultValue.rawValue:
            return defaultValue
        case CodingKeys.deprecationReason.rawValue:
            return deprecationReason
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
    public let interfaces: [GraphQLInterfaceType]
    public let astNode: InterfaceTypeDefinition?
    public let extensionASTNodes: [InterfaceExtensionDefinition]
    public let kind: TypeKind = .interface

    public init(
        name: String,
        description: String? = nil,
        interfaces: [GraphQLInterfaceType] = [],
        fields: GraphQLFieldMap,
        resolveType: GraphQLTypeResolve? = nil,
        astNode: InterfaceTypeDefinition? = nil,
        extensionASTNodes: [InterfaceExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description

        self.fields = try defineFieldMap(
            name: name,
            fields: fields
        )

        self.interfaces = interfaces
        self.resolveType = resolveType
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLInterfaceType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case fields
        case kind
    }
}

extension GraphQLInterfaceType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.fields.rawValue:
            return fields
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLInterfaceType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLInterfaceType: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLInterfaceType, rhs: GraphQLInterfaceType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

public typealias GraphQLUnionTypeExtensions = [String: String]?

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
    public let kind: TypeKind = .union
    public let name: String
    public let description: String?
    public let resolveType: GraphQLTypeResolve?
    public let types: [GraphQLObjectType]
    public let possibleTypeNames: [String: Bool]
    let extensions: [GraphQLUnionTypeExtensions]
    let astNode: UnionTypeDefinition?
    let extensionASTNodes: [UnionExtensionDefinition]

    public init(
        name: String,
        description: String? = nil,
        resolveType: GraphQLTypeResolve? = nil,
        types: [GraphQLObjectType],
        extensions: [GraphQLUnionTypeExtensions] = [],
        astNode: UnionTypeDefinition? = nil,
        extensionASTNodes: [UnionExtensionDefinition] = []
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

        self.extensions = extensions
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes

        possibleTypeNames = [:]
    }
}

extension GraphQLUnionType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case types
        case kind
    }
}

extension GraphQLUnionType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.types.rawValue:
            return types
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLUnionType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLUnionType: Hashable {
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
    public let astNode: EnumTypeDefinition?
    public let extensionASTNodes: [EnumExtensionDefinition]
    public let valueLookup: [Map: GraphQLEnumValueDefinition]
    public let nameLookup: [String: GraphQLEnumValueDefinition]
    public let kind: TypeKind = .enum

    public init(
        name: String,
        description: String? = nil,
        values: GraphQLEnumValueMap,
        astNode: EnumTypeDefinition? = nil,
        extensionASTNodes: [EnumExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.values = try defineEnumValues(
            name: name,
            valueMap: values
        )
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes

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
        let mapValue = try map(from: value)
        guard let enumValue = valueLookup[mapValue] else {
            throw GraphQLError(
                message: "Enum \"\(name)\" cannot represent value: \(mapValue)."
            )
        }
        return .string(enumValue.name)
    }

    public func parseValue(value: Map) throws -> Map {
        guard let valueStr = value.string else {
            throw GraphQLError(
                message: "Enum \"\(name)\" cannot represent non-string value: \(value)." +
                    didYouMeanEnumValue(unknownValueStr: value.description)
            )
        }
        guard let enumValue = nameLookup[valueStr] else {
            throw GraphQLError(
                message: "Value \"\(valueStr)\" does not exist in \"\(name)\" enum." +
                    didYouMeanEnumValue(unknownValueStr: valueStr)
            )
        }
        return enumValue.value
    }

    public func parseLiteral(valueAST: Value) throws -> Map {
        guard let enumNode = valueAST as? EnumValue else {
            throw GraphQLError(
                message: "Enum \"\(name)\" cannot represent non-enum value: \(print(ast: valueAST))." +
                    didYouMeanEnumValue(unknownValueStr: print(ast: valueAST)),
                nodes: [valueAST]
            )
        }
        guard let enumValue = nameLookup[enumNode.value] else {
            throw GraphQLError(
                message: "Value \"\(enumNode.value)\" does not exist in \"\(name)\" enum." +
                    didYouMeanEnumValue(unknownValueStr: enumNode.value),
                nodes: [valueAST]
            )
        }
        return enumValue.value
    }

    private func didYouMeanEnumValue(unknownValueStr: String) -> String {
        let allNames = values.map { $0.name }
        let suggestedValues = suggestionList(input: unknownValueStr, options: allNames)
        return didYouMean("the enum value", suggestions: suggestedValues)
    }
}

extension GraphQLEnumType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case values
        case kind
    }
}

extension GraphQLEnumType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.values.rawValue:
            return values
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLEnumType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLEnumType: Hashable {
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
            value: value.value,
            astNode: value.astNode
        )

        definitions.append(definition)
    }

    return definitions
}

public typealias GraphQLEnumValueMap = OrderedDictionary<String, GraphQLEnumValue>

public struct GraphQLEnumValue {
    public let value: Map
    public let description: String?
    public let deprecationReason: String?
    public let astNode: EnumValueDefinition?

    public init(
        value: Map,
        description: String? = nil,
        deprecationReason: String? = nil,
        astNode: EnumValueDefinition? = nil
    ) {
        self.value = value
        self.description = description
        self.deprecationReason = deprecationReason
        self.astNode = astNode
    }
}

public struct GraphQLEnumValueDefinition: Encodable {
    private enum CodingKeys: String, CodingKey {
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
    public let astNode: EnumValueDefinition?

    public init(
        name: String,
        description: String?,
        deprecationReason: String?,
        isDeprecated: Bool,
        value: Map,
        astNode: EnumValueDefinition? = nil
    ) {
        self.name = name
        self.description = description
        self.deprecationReason = deprecationReason
        self.isDeprecated = isDeprecated
        self.value = value
        self.astNode = astNode
    }
}

extension GraphQLEnumValueDefinition: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.deprecationReason.rawValue:
            return deprecationReason
        case CodingKeys.isDeprecated.rawValue:
            return isDeprecated
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
    public let fields: InputObjectFieldDefinitionMap
    public let astNode: InputObjectTypeDefinition?
    public let extensionASTNodes: [InputObjectExtensionDefinition]
    public let isOneOf: Bool
    public let kind: TypeKind = .inputObject

    public init(
        name: String,
        description: String? = nil,
        fields: InputObjectFieldMap = [:],
        astNode: InputObjectTypeDefinition? = nil,
        extensionASTNodes: [InputObjectExtensionDefinition] = [],
        isOneOf: Bool = false
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = try defineInputObjectFieldMap(
            name: name,
            fields: fields
        )
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
        self.isOneOf = isOneOf
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }

    func getFields() -> InputObjectFieldDefinitionMap {
        return fields
    }
}

extension GraphQLInputObjectType: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case fields
        case isOneOf
        case kind
    }
}

extension GraphQLInputObjectType: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.fields.rawValue:
            return fields
        case CodingKeys.isOneOf.rawValue:
            return isOneOf
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLInputObjectType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}

extension GraphQLInputObjectType: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLInputObjectType, rhs: GraphQLInputObjectType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

func defineInputObjectFieldMap(
    name: String,
    fields: InputObjectFieldMap
) throws -> InputObjectFieldDefinitionMap {
    guard !fields.isEmpty else {
        throw GraphQLError(
            message:
            "\(name) fields must be an object with field names as " +
                "keys or a function which returns such an object."
        )
    }

    var definitionMap = InputObjectFieldDefinitionMap()

    for (name, field) in fields {
        try assertValid(name: name)

        let definition = InputObjectFieldDefinition(
            name: name,
            type: field.type,
            description: field.description,
            defaultValue: field.defaultValue,
            deprecationReason: field.deprecationReason,
            astNode: field.astNode
        )

        definitionMap[name] = definition
    }

    return definitionMap
}

public struct InputObjectField {
    public let type: GraphQLInputType
    public let defaultValue: Map?
    public let description: String?
    public let deprecationReason: String?
    public let astNode: InputValueDefinition?

    public init(
        type: GraphQLInputType,
        defaultValue: Map? = nil,
        description: String? = nil,
        deprecationReason: String? = nil,
        astNode: InputValueDefinition? = nil
    ) {
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.deprecationReason = deprecationReason
        self.astNode = astNode
    }
}

public typealias InputObjectFieldMap = OrderedDictionary<String, InputObjectField>

public final class InputObjectFieldDefinition {
    public let name: String
    public internal(set) var type: GraphQLInputType
    public let description: String?
    public let defaultValue: Map?
    public let deprecationReason: String?
    public let astNode: InputValueDefinition?

    init(
        name: String,
        type: GraphQLInputType,
        description: String? = nil,
        defaultValue: Map? = nil,
        deprecationReason: String? = nil,
        astNode: InputValueDefinition? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
        self.deprecationReason = deprecationReason
        self.astNode = astNode
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        let resolvedType = try resolveTypeReference(type: type, typeMap: typeMap)

        guard let inputType = resolvedType as? GraphQLInputType else {
            throw GraphQLError(
                message: "Resolved type \"\(resolvedType)\" is not a valid input type."
            )
        }

        type = inputType
    }
}

extension InputObjectFieldDefinition: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case defaultValue
        case deprecationReason
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(AnyEncodable(type), forKey: .type)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(deprecationReason, forKey: .deprecationReason)
    }
}

extension InputObjectFieldDefinition: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.name.rawValue:
            return name
        case CodingKeys.description.rawValue:
            return description
        case CodingKeys.type.rawValue:
            return type
        case CodingKeys.defaultValue.rawValue:
            return defaultValue
        case CodingKeys.deprecationReason.rawValue:
            return deprecationReason
        default:
            return nil
        }
    }
}

public func isRequiredInputField(_ field: InputObjectFieldDefinition) -> Bool {
    return field.type is GraphQLNonNull && field.defaultValue == nil
}

public typealias InputObjectFieldDefinitionMap = OrderedDictionary<
    String,
    InputObjectFieldDefinition
>

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
        ofType = type
    }

    public init(_ name: String) {
        ofType = GraphQLTypeReference(name)
    }

    var wrappedType: GraphQLType {
        return ofType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLList {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)
        return GraphQLList(resolvedType)
    }
}

extension GraphQLList: Encodable {
    private enum CodingKeys: String, CodingKey {
        case ofType
        case kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AnyEncodable(ofType), forKey: .ofType)
        try container.encode(kind, forKey: .kind)
    }
}

extension GraphQLList: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.ofType.rawValue:
            return ofType
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLList: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[" + ofType.debugDescription + "]"
    }
}

extension GraphQLList: Hashable {
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

    public init(_ type: GraphQLType) throws {
        guard let type = type as? GraphQLNullableType else {
            throw GraphQLError(message: "type is already non null: \(type.debugDescription)")
        }
        ofType = type
    }

    public init(_ type: GraphQLNullableType) {
        ofType = type
    }

    public init(_ name: String) {
        ofType = GraphQLTypeReference(name)
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

extension GraphQLNonNull: Encodable {
    private enum CodingKeys: String, CodingKey {
        case ofType
        case kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AnyEncodable(ofType), forKey: .ofType)
        try container.encode(kind, forKey: .kind)
    }
}

extension GraphQLNonNull: KeySubscriptable {
    public subscript(key: String) -> Any? {
        switch key {
        case CodingKeys.ofType.rawValue:
            return ofType
        case CodingKeys.kind.rawValue:
            return kind
        default:
            return nil
        }
    }
}

extension GraphQLNonNull: CustomDebugStringConvertible {
    public var debugDescription: String {
        return ofType.debugDescription + "!"
    }
}

extension GraphQLNonNull: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: GraphQLNonNull, rhs: GraphQLNonNull) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

/**
 * A special type to allow object/interface/input types to reference itself. It's replaced with the real type
 * object when the schema is built.
 */
public final class GraphQLTypeReference: GraphQLType, GraphQLOutputType, GraphQLInputType,
    GraphQLNullableType, GraphQLNamedType
{
    public let name: String
    public let kind: TypeKind = .typeReference

    public init(_ name: String) {
        self.name = name
    }
}

extension GraphQLTypeReference: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
    }
}

extension GraphQLTypeReference: KeySubscriptable {
    public subscript(_: String) -> Any? {
        switch name {
        case CodingKeys.name.rawValue:
            return name
        default:
            return nil
        }
    }
}

extension GraphQLTypeReference: CustomDebugStringConvertible {
    public var debugDescription: String {
        return name
    }
}
