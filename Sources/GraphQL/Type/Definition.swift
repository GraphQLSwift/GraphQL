import Foundation
import NIO
import OrderedCollections

/**
 * These are all of the possible kinds of types.
 */
public protocol GraphQLType: CustomDebugStringConvertible {}
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
 * itself in a field, you can use a closure to supply the fields lazily.
 *
 * Example:
 *
 *     let PersonType = GraphQLObjectType(
 *         name: "Person",
 *         fields: {
 *         [
 *             "name": GraphQLField(type: GraphQLString),
 *             "bestFriend": GraphQLField(type: PersonType),
 *         ]
 *         }
 *     )
 *
 */
public final class GraphQLObjectType {
    public let name: String
    public let description: String?
    public var fields: () throws -> GraphQLFieldMap
    public var interfaces: () throws -> [GraphQLInterfaceType]
    public let isTypeOf: GraphQLIsTypeOf?
    public let astNode: ObjectTypeDefinition?
    public let extensionASTNodes: [TypeExtensionDefinition]
    public let kind: TypeKind = .object

    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap = [:],
        interfaces: [GraphQLInterfaceType] = [],
        isTypeOf: GraphQLIsTypeOf? = nil,
        astNode: ObjectTypeDefinition? = nil,
        extensionASTNodes: [TypeExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = { fields }
        self.interfaces = { interfaces }
        self.isTypeOf = isTypeOf
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    public init(
        name: String,
        description: String? = nil,
        fields: @escaping () throws -> GraphQLFieldMap,
        interfaces: @escaping () throws -> [GraphQLInterfaceType] = { [] },
        isTypeOf: GraphQLIsTypeOf? = nil,
        astNode: ObjectTypeDefinition? = nil,
        extensionASTNodes: [TypeExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = fields
        self.interfaces = interfaces
        self.isTypeOf = isTypeOf
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    func getFields() throws -> GraphQLFieldDefinitionMap {
        try defineFieldMap(
            name: name,
            fields: fields()
        )
    }

    func getInterfaces() throws -> [GraphQLInterfaceType] {
        return try interfaces()
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
    public var fields: () throws -> GraphQLFieldMap
    public var interfaces: () throws -> [GraphQLInterfaceType]
    public let astNode: InterfaceTypeDefinition?
    public let extensionASTNodes: [InterfaceExtensionDefinition]
    public let kind: TypeKind = .interface

    public init(
        name: String,
        description: String? = nil,
        interfaces: [GraphQLInterfaceType] = [],
        fields: GraphQLFieldMap = [:],
        resolveType: GraphQLTypeResolve? = nil,
        astNode: InterfaceTypeDefinition? = nil,
        extensionASTNodes: [InterfaceExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = { fields }
        self.interfaces = { interfaces }
        self.resolveType = resolveType
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    public init(
        name: String,
        description: String? = nil,
        fields: @escaping () throws -> GraphQLFieldMap,
        interfaces: @escaping () throws -> [GraphQLInterfaceType] = { [] },
        resolveType: GraphQLTypeResolve? = nil,
        astNode: InterfaceTypeDefinition? = nil,
        extensionASTNodes: [InterfaceExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = fields
        self.interfaces = interfaces
        self.resolveType = resolveType
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
    }

    func getFields() throws -> GraphQLFieldDefinitionMap {
        try defineFieldMap(
            name: name,
            fields: fields()
        )
    }

    func getInterfaces() throws -> [GraphQLInterfaceType] {
        return try interfaces()
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
    public let types: () throws -> [GraphQLObjectType]
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

        self.types = { types }

        self.extensions = extensions
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes

        possibleTypeNames = [:]
    }

    public init(
        name: String,
        description: String? = nil,
        resolveType: GraphQLTypeResolve? = nil,
        types: @escaping () throws -> [GraphQLObjectType],
        extensions: [GraphQLUnionTypeExtensions] = [],
        astNode: UnionTypeDefinition? = nil,
        extensionASTNodes: [UnionExtensionDefinition] = []
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.resolveType = resolveType

        self.types = types

        self.extensions = extensions
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes

        possibleTypeNames = [:]
    }

    func getTypes() throws -> [GraphQLObjectType] {
        try types()
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

public struct GraphQLEnumValueDefinition {
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
    public var fields: () throws -> InputObjectFieldMap
    public let astNode: InputObjectTypeDefinition?
    public let extensionASTNodes: [InputObjectExtensionDefinition]
    public let isOneOf: Bool
    public let kind: TypeKind = .inputObject

    public init(
        name: String,
        description: String? = nil,
        fields: @escaping () throws -> InputObjectFieldMap,
        astNode: InputObjectTypeDefinition? = nil,
        extensionASTNodes: [InputObjectExtensionDefinition] = [],
        isOneOf: Bool = false
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.fields = fields
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
        self.isOneOf = isOneOf
    }

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
        self.fields = {
            fields
        }
        self.astNode = astNode
        self.extensionASTNodes = extensionASTNodes
        self.isOneOf = isOneOf
    }

    func getFields() throws -> InputObjectFieldDefinitionMap {
        try defineInputObjectFieldMap(
            name: name,
            fields: fields()
        )
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

    var wrappedType: GraphQLType {
        return ofType
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

    var wrappedType: GraphQLType {
        return ofType
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
