/**
 * These are all of the possible kinds of types.
 */
public protocol GraphQLType : CustomStringConvertible, CustomDebugStringConvertible, MapRepresentable {}
extension GraphQLScalarType : GraphQLType {}
extension GraphQLObjectType : GraphQLType {}
extension GraphQLInterfaceType : GraphQLType {}
extension GraphQLUnionType : GraphQLType {}
extension GraphQLEnumType : GraphQLType {}
extension GraphQLInputObjectType : GraphQLType {}
extension GraphQLList : GraphQLType {}
extension GraphQLNonNull : GraphQLType {}

func isType(type: Any) -> Bool {
    return type is GraphQLType
}

/**
 * These types may be used as input types for arguments and directives.
 */
public protocol GraphQLInputType : GraphQLType {}
extension GraphQLScalarType : GraphQLInputType {}
extension GraphQLEnumType : GraphQLInputType {}
extension GraphQLInputObjectType : GraphQLInputType {}
extension GraphQLList : GraphQLInputType {}
extension GraphQLNonNull : GraphQLInputType {}
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
public protocol GraphQLOutputType : GraphQLType {}
extension GraphQLScalarType : GraphQLOutputType {}
extension GraphQLObjectType : GraphQLOutputType {}
extension GraphQLInterfaceType : GraphQLOutputType {}
extension GraphQLUnionType : GraphQLOutputType {}
extension GraphQLEnumType : GraphQLOutputType {}
extension GraphQLList : GraphQLOutputType {}
extension GraphQLNonNull : GraphQLOutputType {}
// TODO: Conditional conformances
//extension GraphQLList : GraphQLOutputType where Element : GraphQLOutputType {}
//extension GraphQLNonNull : GraphQLInputType where Element : (GraphQLScalarType | GraphQLObjectType | GraphQLInterfaceType | GraphQLUnionType | GraphQLEnumType | GraphQLList<GraphQLOutputType>) {}

func isOutputType(type: GraphQLType?) -> Bool {
    let namedType = getNamedType(type: type)

    return namedType is GraphQLScalarType    ||
           namedType is GraphQLObjectType    ||
           namedType is GraphQLInterfaceType ||
           namedType is GraphQLUnionType     ||
           namedType is GraphQLEnumType
}

/**
 * These types may describe types which may be leaf values.
 */
public protocol GraphQLLeafType : GraphQLType, GraphQLNamedType {
    func serialize(value: Map) throws -> Map?
    func parseValue(value: Map) throws -> Map?
    func parseLiteral(valueAST: Value) throws -> Map?
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
public protocol GraphQLCompositeType : GraphQLType, GraphQLNamedType, GraphQLOutputType {}
extension GraphQLObjectType : GraphQLCompositeType {}
extension GraphQLInterfaceType : GraphQLCompositeType {}
extension GraphQLUnionType : GraphQLCompositeType {}

func isCompositeType(type: GraphQLType?) -> Bool {
    return type is GraphQLObjectType    ||
           type is GraphQLInterfaceType ||
           type is GraphQLUnionType
}

protocol GraphQLTypeReferenceContainer : GraphQLNamedType {
    func replaceTypeReferences(typeMap: TypeMap) throws
}

extension GraphQLObjectType : GraphQLTypeReferenceContainer {}
extension GraphQLInterfaceType : GraphQLTypeReferenceContainer {}

/**
 * These types may describe the parent context of a selection set.
 */
public protocol GraphQLAbstractType : GraphQLType, GraphQLNamedType {
    var resolveType: GraphQLTypeResolve? { get }
}

extension GraphQLInterfaceType : GraphQLAbstractType {}
extension GraphQLUnionType : GraphQLAbstractType {}

/**
 * These types can all accept null as a value.
 */
public protocol GraphQLNullableType : GraphQLType {}
extension GraphQLScalarType : GraphQLNullableType {}
extension GraphQLObjectType : GraphQLNullableType {}
extension GraphQLInterfaceType : GraphQLNullableType {}
extension GraphQLUnionType : GraphQLNullableType {}
extension GraphQLEnumType : GraphQLNullableType {}
extension GraphQLInputObjectType : GraphQLNullableType {}
extension GraphQLList : GraphQLNullableType {}

func getNullableType(type: GraphQLType?) -> GraphQLNullableType? {
    if let type = type as? GraphQLNonNull {
        return type.ofType
    }

    return type as? GraphQLNullableType
}

/**
 * These named types do not include modifiers like List or NonNull.
 */
public protocol GraphQLNamedType : GraphQLType, GraphQLNullableType, MapRepresentable {
    var name: String { get }
}

extension GraphQLScalarType : GraphQLNamedType {}
extension GraphQLObjectType : GraphQLNamedType {}
extension GraphQLInterfaceType : GraphQLNamedType {}
extension GraphQLUnionType : GraphQLNamedType {}
extension GraphQLEnumType : GraphQLNamedType {}
extension GraphQLInputObjectType : GraphQLNamedType {}

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
protocol GraphQLWrapperType : GraphQLType {
    var wrappedType: GraphQLType { get }
}

extension GraphQLList : GraphQLWrapperType {}
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
 *     let oddType = try ScalarType(name: "Odd", serialize: { $0 % 2 == 1 ? $0 : nil })
 *
 */
public final class GraphQLScalarType {
    public let name: String
    let scalarDescription: String?
    let serialize: (Map) throws -> Map?
    let parseValue: ((Map) throws -> Map?)?
    let parseLiteral: ((Value) throws -> Map?)?

    public init(
        name: String,
        description: String? = nil,
        serialize: @escaping (Map) throws -> Map?
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.scalarDescription = description
        self.serialize = serialize
        self.parseValue = nil
        self.parseLiteral = nil
    }

    init(
        name: String,
        description: String? = nil,
        serialize: @escaping (Map) throws -> Map?,
        parseValue: @escaping (Map) throws -> Map?,
        parseLiteral: @escaping (Value) throws -> Map?
    ) throws {
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
}

extension GraphQLScalarType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLScalarType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLScalarType(name:\(name.debugDescription),description:\(scalarDescription.debugDescription))"
    }
}

extension GraphQLScalarType {
    public var map: Map {
        return [
            "name": name.map,
            "description": scalarDescription.map,
            "kind": TypeKind.scalar.rawValue.map,
        ]
    }
}

extension GraphQLScalarType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
public final class GraphQLObjectType {
    public let name: String
    let objectDescription: String?
    var fields: GraphQLFieldDefinitionMap
    let interfaces: [GraphQLInterfaceType]
    let isTypeOf: GraphQLIsTypeOf?

    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap,
        interfaces: [GraphQLInterfaceType] = [],
        isTypeOf: GraphQLIsTypeOf? = nil
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.objectDescription = description
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

    init(
        name: String,
        objectDescription: String?,
        fields: GraphQLFieldDefinitionMap,
        interfaces: [GraphQLInterfaceType],
        isTypeOf: GraphQLIsTypeOf?
    ) {
        self.name = name
        self.objectDescription = objectDescription
        self.fields = fields
        self.interfaces = interfaces
        self.isTypeOf = isTypeOf
    }



    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLObjectType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLObjectType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLObjectType(name:\(name.debugDescription),description:\(objectDescription.debugDescription),fields:\(fields.debugDescription),interfaces:\(interfaces.debugDescription))"
    }
}

extension GraphQLObjectType {
    public var map: Map {
        return [
            "name": name.map,
            "description": objectDescription.map,
            "fields": fields.map,
            "interfaces": interfaces.map,
            "kind": TypeKind.object.rawValue.map,
        ]
    }
}

extension GraphQLObjectType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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

public enum TypeResolveResult {
    case type(GraphQLObjectType)
    case name(String)
}

public typealias GraphQLTypeResolve = (
    _ value: Map,
    _ context: Map,
    _ info: GraphQLResolveInfo
) throws -> TypeResolveResult

public typealias GraphQLIsTypeOf = (
    _ source: Map,
    _ context: Map,
    _ info: GraphQLResolveInfo
) -> Bool

public typealias GraphQLFieldResolve = (
    _ source: Map,
    _ args: [String: Map],
    _ context: Map,
    _ info: GraphQLResolveInfo
) throws -> Map

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

public typealias GraphQLFieldMap = [String: GraphQLField]

public struct GraphQLField {
    let type: GraphQLOutputType
    let args: GraphQLArgumentConfigMap
    let deprecationReason: String?
    let description: String?
    let resolve: GraphQLFieldResolve?

    public init(
        type: GraphQLOutputType,
        description: String? = nil,
        deprecationReason: String? = nil,
        args: GraphQLArgumentConfigMap = [:],
        resolve: GraphQLFieldResolve? = nil
    ) {
        self.type = type
        self.args = args
        self.deprecationReason = deprecationReason
        self.description = description
        self.resolve = resolve
    }
}

public typealias GraphQLFieldDefinitionMap = [String: GraphQLFieldDefinition]

public final class GraphQLFieldDefinition {
    let name: String
    let description: String?
    var type: GraphQLOutputType
    let args: [GraphQLArgumentDefinition]
    let resolve: GraphQLFieldResolve?
    let deprecationReason: String?

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
    }

    var isDeprecated: Bool {
        return deprecationReason != nil
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

extension GraphQLFieldDefinition : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLObjectType(name:\(name.debugDescription),description:\(description.debugDescription),type:\(type.debugDescription),args:\(args.debugDescription),deprecationReason:\(deprecationReason.debugDescription),isDeprecated:\(isDeprecated))"
    }
}

extension GraphQLFieldDefinition : MapRepresentable {
    public var map: Map {
        return [
            "name": name.map,
            "description": description.map,
            "type": type.map,
            "args": args.map,
            "deprecationReason": deprecationReason.map,
            "isDeprecated": isDeprecated.map,
        ]
    }
}

public typealias GraphQLArgumentConfigMap = [String: GraphQLArgument]

public struct GraphQLArgument {
    let type: GraphQLInputType
    let description: String?
    let defaultValue: Map?

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
    let name: String
    let type: GraphQLInputType
    let defaultValue: Map?
    let description: String?

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

extension GraphQLArgumentDefinition : MapRepresentable {
    public var map: Map {
        return [
            "name": name.map,
            "description": description.map,
            "type": type.map,
            "defaultValue": defaultValue.map,
        ]
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
 *     const EntityType = new GraphQLInterfaceType({
 *       name: 'Entity',
 *       fields: {
 *         name: { type: GraphQLString }
 *       }
 *     });
 *
 */
public final class GraphQLInterfaceType {
    public let name: String
    let interfaceDescription: String?
    public let resolveType: GraphQLTypeResolve?

    let fields: GraphQLFieldDefinitionMap

    public init(
        name: String,
        description: String? = nil,
        fields: GraphQLFieldMap,
        resolveType: GraphQLTypeResolve? = nil
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.interfaceDescription = description
        self.fields = try defineFieldMap(
            name: name,
            fields: fields
        )
        self.resolveType = resolveType
    }

    init(
        name: String,
        interfaceDescription: String?,
        fields: GraphQLFieldDefinitionMap,
        resolveType: GraphQLTypeResolve?
    ) {
        self.name = name
        self.interfaceDescription = interfaceDescription
        self.fields = fields
        self.resolveType = resolveType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws {
        for field in fields {
            try field.value.replaceTypeReferences(typeMap: typeMap)
        }
    }
}

extension GraphQLInterfaceType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLInterfaceType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLInterfaceType(name:\(name.debugDescription),description:\(interfaceDescription.debugDescription),fields:\(fields.debugDescription))"
    }
}

extension GraphQLInterfaceType {
    public var map: Map {
        return [
            "name": name.map,
            "description": interfaceDescription.map,
            "fields": fields.map,
            "kind": TypeKind.interface.rawValue.map,
        ]
    }
}

extension GraphQLInterfaceType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
 *                 return nil
 *             }
 *         }
 *     )
 *
 */
public final class GraphQLUnionType {
    public let name: String
    let unionDescription: String?
    public let resolveType: GraphQLTypeResolve?

    let types: [GraphQLObjectType]
    let possibleTypeNames: [String: Bool]

    init(
        name: String,
        description: String? = nil,
        resolveType: GraphQLTypeResolve? = nil,
        types: [GraphQLObjectType]
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.unionDescription = description
        self.resolveType = resolveType
        self.types = try defineTypes(
            name: name,
            hasResolve: resolveType != nil,
            types: types
        )
        self.possibleTypeNames = [:]
    }
}

extension GraphQLUnionType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLUnionType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLUnionType(name:\(name.debugDescription),description:\(unionDescription.debugDescription),types:\(types.debugDescription))"
    }
}

extension GraphQLUnionType {
    public var map: Map {
        return [
            "name": name.map,
            "description": unionDescription.map,
            "types": types.map,
            "kind": TypeKind.union.rawValue.map,
        ]
    }
}

extension GraphQLUnionType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
public final class GraphQLEnumType {
    public let name: String
    let enumDescription: String?

    let values: [GraphQLEnumValueDefinition]
    let valueLookup: [Map: GraphQLEnumValueDefinition]
    let nameLookup: [String: GraphQLEnumValueDefinition]

    public init(
        name: String,
        description: String? = nil,
        values: GraphQLEnumValueMap
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.enumDescription = description
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
}

extension GraphQLEnumType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLEnumType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLEnumType(name:\(name.debugDescription),description:\(enumDescription.debugDescription),values:\(values.debugDescription))"
    }
}

extension GraphQLEnumType {
    public var map: Map {
        return [
            "name": name.map,
            "description": enumDescription.map,
            "values": values.map,
            "kind": TypeKind.enum.rawValue.map,
        ]
    }
}

extension GraphQLEnumType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
            value: value.value
        )

        definitions.append(definition)
    }

    return definitions
}

public typealias GraphQLEnumValueMap = [String: GraphQLEnumValue]

public struct GraphQLEnumValue {
    let value: Map
    let description: String?
    let deprecationReason: String?

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

struct GraphQLEnumValueDefinition {
    let name: String
    let description: String?
    let deprecationReason: String?
    let value: Map

    var isDeprecated: Bool {
        return deprecationReason != nil
    }
}

extension GraphQLEnumValueDefinition : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLEnumType(name:\(name.debugDescription),description:\(description.debugDescription),value:\(value),deprecationReason:\(deprecationReason.debugDescription),isDeprecated:\(isDeprecated))"
    }
}

extension GraphQLEnumValueDefinition : MapRepresentable {
    var map: Map {
        return [
            "name": name.map,
            "description": description.map,
            "deprecationReason": deprecationReason.map,
            "isDeprecated": isDeprecated.map
        ]
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
    let inputObjectDescription: String?

    let fields: InputObjectFieldMap

    init(
        name: String,
        description: String? = nil,
        fields: InputObjectConfigFieldMap
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.inputObjectDescription = description
        self.fields = try defineInputObjectFieldMap(
            name: name,
            fields: fields
        )
    }
}

extension GraphQLInputObjectType : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLInputObjectType : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLInputObjectType(name:\(name.debugDescription),description:\(inputObjectDescription.debugDescription),fields:\(fields.debugDescription))"
    }
}

extension GraphQLInputObjectType {
    public var map: Map {
        return [
            "name": name.map,
            "description": inputObjectDescription.map,
            "fields": fields.map,
            "kind": TypeKind.inputObject.rawValue.map,
        ]
    }
}

extension GraphQLInputObjectType : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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

struct InputObjectField {
    let type: GraphQLInputType
    let defaultValue: Map?
    let description: String?
}

typealias InputObjectConfigFieldMap = [String: InputObjectField]

struct InputObjectFieldDefinition {
    let name: String
    let description: String?
    let type: GraphQLInputType
    let defaultValue: Map?
}

extension InputObjectFieldDefinition : MapRepresentable {
    var map: Map {
        return [
            "name": name.map,
            "description": description.map,
            "type": type.map,
            "defaultValue": defaultValue.map,
        ]
    }
}

typealias InputObjectFieldMap = [String: InputObjectFieldDefinition]

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
public final class GraphQLList {
    let ofType: GraphQLType

    public init(_ type: GraphQLType) {
        self.ofType = type
    }

    var wrappedType: GraphQLType {
        return ofType
    }

    func replaceTypeReferences(typeMap: TypeMap) throws -> GraphQLList {
        let resolvedType = try resolveTypeReference(type: ofType, typeMap: typeMap)
        return GraphQLList(resolvedType)
    }
}

extension GraphQLList : CustomStringConvertible {
    public var description: String {
        return "[" + ofType.description + "]"
    }
}

extension GraphQLList : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLList(ofType:\(ofType.debugDescription))"
    }
}

extension GraphQLList {
    public var map: Map {
        return [
            "ofType": ofType.map,
            "kind": TypeKind.list.rawValue.map,
        ]
    }
}

extension GraphQLList : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
 *     const RowType = new GraphQLObjectType({
 *       name: 'Row',
 *       fields: () => ({
 *         id: { type: new GraphQLNonNull(GraphQLString) },
 *       })
 *     })
 *
 * Note: the enforcement of non-nullability occurs within the executor.
 */
public final class GraphQLNonNull {
    let ofType: GraphQLNullableType
    
    public init(_ type: GraphQLNullableType) {
        self.ofType = type
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

extension GraphQLNonNull : CustomStringConvertible {
    public var description: String {
        return ofType.description + "!"
    }
}

extension GraphQLNonNull : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLNonNull(ofType:\(ofType.debugDescription))"
    }
}

extension GraphQLNonNull {
    public var map: Map {
        return [
            "ofType": ofType.map,
            "kind": TypeKind.nonNull.rawValue.map,
        ]
    }
}

extension GraphQLNonNull : Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
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
    let name: String

    public init(_ name: String) {
        self.name = name
    }
}

extension GraphQLTypeReference : CustomStringConvertible {
    public var description: String {
        return name
    }
}

extension GraphQLTypeReference : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "GraphQLTypeReference(name:\(name.debugDescription))"
    }
}

extension GraphQLTypeReference {
    public var map: Map {
        return [
            "name": name.map,
            "kind": TypeKind.typeReference.rawValue.map,
        ]
    }
}
