import NIO

let __Schema = try! GraphQLObjectType(
    name: "__Schema",
    description:
    "A GraphQL Schema defines the capabilities of a GraphQL server. It " +
    "exposes all available types and directives on the server, as well as " +
    "the entry points for query, mutation, and subscription operations.",
    fields: [
        "types": GraphQLField(
            type: GraphQLNonNull(GraphQLList(GraphQLNonNull(__Type))),
            description: "A list of all types supported by this server.",
            resolve: { schema, _, _, _ -> [GraphQLNamedType]? in
                guard let schema = schema as? GraphQLSchema else {
                    return nil
                }

                let typeMap = schema.typeMap
                return Array(typeMap.values).sorted(by: { $0.name < $1.name })
            }
        ),
        "queryType": GraphQLField(
            type: GraphQLNonNull(__Type),
            description: "The type that query operations will be rooted at.",
            resolve: { schema, _, _, _ -> GraphQLObjectType? in
                guard let schema = schema as? GraphQLSchema else {
                    return nil
                }

                return schema.queryType
            }
        ),
        "mutationType": GraphQLField(
            type: __Type,
            description:
            "If this server supports mutation, the type that " +
            "mutation operations will be rooted at.",
            resolve: { schema, _, _, _ -> GraphQLObjectType? in
                guard let schema = schema as? GraphQLSchema else {
                    return nil
                }

                return schema.mutationType
            }
        ),
        "subscriptionType": GraphQLField(
            type: __Type,
            description:
            "If this server support subscription, the type that " +
            "subscription operations will be rooted at.",
            resolve: { schema, _, _, _ -> GraphQLObjectType? in
                guard let schema = schema as? GraphQLSchema else {
                    return nil
                }

                return schema.subscriptionType
            }
        ),
        "directives": GraphQLField(
            type: GraphQLNonNull(GraphQLList(GraphQLNonNull(__Directive))),
            description: "A list of all directives supported by this server.",
            resolve: { schema, _, _, _ -> [GraphQLDirective]? in
                guard let schema = schema as? GraphQLSchema else {
                    return nil
                }

                return schema.directives
            }
        )
    ]
)

let __Directive = try! GraphQLObjectType(
    name: "__Directive",
    description:
    "A Directive provides a way to describe alternate runtime execution and " +
    "type validation behavior in a GraphQL document." +
    "\n\nIn some cases, you need to provide options to alter GraphQL\"s " +
    "execution behavior in ways field arguments will not suffice, such as " +
    "conditionally including or skipping a field. Directives provide this by " +
    "describing additional information to the executor.",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "description": GraphQLField(type: GraphQLString),
        "locations": GraphQLField(type: GraphQLNonNull(GraphQLList(GraphQLNonNull(__DirectiveLocation)))),
        "args": GraphQLField(
            type: GraphQLNonNull(GraphQLList(GraphQLNonNull(__InputValue))),
            resolve: { directive, _, _, _ -> [GraphQLArgumentDefinition]? in
                guard let directive = directive as? GraphQLDirective else {
                    return nil
                }

                return directive.args
            }
        )
    ]
)

let __DirectiveLocation = try! GraphQLEnumType(
    name: "__DirectiveLocation",
    description:
    "A Directive can be adjacent to many parts of the GraphQL language, a " +
    "__DirectiveLocation describes one such possible adjacencies.",
    values: [
        "QUERY": GraphQLEnumValue(
            value: Map(DirectiveLocation.query.rawValue),
            description: "Location adjacent to a query operation."
        ),
        "MUTATION": GraphQLEnumValue(
            value: Map(DirectiveLocation.mutation.rawValue),
            description: "Location adjacent to a mutation operation."
        ),
        "SUBSCRIPTION": GraphQLEnumValue(
            value: Map(DirectiveLocation.subscription.rawValue),
            description: "Location adjacent to a subscription operation."
        ),
        "FIELD": GraphQLEnumValue(
            value: Map(DirectiveLocation.field.rawValue),
            description: "Location adjacent to a field."
        ),
        "FRAGMENT_DEFINITION": GraphQLEnumValue(
            value: Map(DirectiveLocation.fragmentDefinition.rawValue),
            description: "Location adjacent to a fragment definition."
        ),
        "FRAGMENT_SPREAD": GraphQLEnumValue(
            value: Map(DirectiveLocation.fragmentSpread.rawValue),
            description: "Location adjacent to a fragment spread."
        ),
        "INLINE_FRAGMENT": GraphQLEnumValue(
            value: Map(DirectiveLocation.inlineFragment.rawValue),
            description: "Location adjacent to an inline fragment."
        ),
        "SCHEMA": GraphQLEnumValue(
            value: Map(DirectiveLocation.schema.rawValue),
            description: "Location adjacent to a schema definition."
        ),
        "SCALAR": GraphQLEnumValue(
            value: Map(DirectiveLocation.scalar.rawValue),
            description: "Location adjacent to a scalar definition."
        ),
        "OBJECT": GraphQLEnumValue(
            value: Map(DirectiveLocation.object.rawValue),
            description: "Location adjacent to an object type definition."
        ),
        "FIELD_DEFINITION": GraphQLEnumValue(
            value: Map(DirectiveLocation.fieldDefinition.rawValue),
            description: "Location adjacent to a field definition."
        ),
        "ARGUMENT_DEFINITION": GraphQLEnumValue(
            value: Map(DirectiveLocation.argumentDefinition.rawValue),
            description: "Location adjacent to an argument definition."
        ),
        "INTERFACE": GraphQLEnumValue(
            value: Map(DirectiveLocation.interface.rawValue),
            description: "Location adjacent to an interface definition."
        ),
        "UNION": GraphQLEnumValue(
            value: Map(DirectiveLocation.union.rawValue),
            description: "Location adjacent to a union definition."
        ),
        "ENUM": GraphQLEnumValue(
            value: Map(DirectiveLocation.enum.rawValue),
            description: "Location adjacent to an enum definition."
        ),
        "ENUM_VALUE": GraphQLEnumValue(
            value: Map(DirectiveLocation.enumValue.rawValue),
            description: "Location adjacent to an enum value definition."
        ),
        "INPUT_OBJECT": GraphQLEnumValue(
            value: Map(DirectiveLocation.inputObject.rawValue),
            description: "Location adjacent to an input object type definition."
        ),
        "INPUT_FIELD_DEFINITION": GraphQLEnumValue(
            value: Map(DirectiveLocation.inputFieldDefinition.rawValue),
            description: "Location adjacent to an input object field definition."
        ),
    ]
)

let __Type: GraphQLObjectType = try! GraphQLObjectType(
    name: "__Type",
    description:
    "The fundamental unit of any GraphQL Schema is the type. There are " +
    "many kinds of types in GraphQL as represented by the `__TypeKind` enum." +
    "\n\nDepending on the kind of a type, certain fields describe " +
    "information about that type. Scalar types provide no information " +
    "beyond a name and description, while Enum types provide their values. " +
    "Object and Interface types provide the fields they describe. Abstract " +
    "types, Union and Interface, provide the Object types possible " +
    "at runtime. List and NonNull types compose other types.",
    fields: [
        "kind": GraphQLField(
            type: GraphQLNonNull(__TypeKind),
            resolve: { type, _, _, _ -> TypeKind? in
                switch type {
                case let type as GraphQLScalarType:
                    return TypeKind.scalar
                case let type as GraphQLObjectType:
                    return TypeKind.object
                case let type as GraphQLInterfaceType:
                    return TypeKind.interface
                case let type as GraphQLUnionType:
                    return TypeKind.union
                case let type as GraphQLEnumType:
                    return TypeKind.enum
                case let type as GraphQLInputObjectType:
                    return TypeKind.inputObject
                case let type as GraphQLList:
                    return TypeKind.list
                case let type as GraphQLNonNull:
                    return TypeKind.nonNull
                default:
                    throw GraphQLError(message: "Unknown kind of type: \(type)")
                }
            }
        ),
        "name": GraphQLField(type: GraphQLString),
        "description": GraphQLField(type: GraphQLString),
        "fields": GraphQLField(
            type: GraphQLList(GraphQLNonNull(__Field)),
            args: [
                "includeDeprecated": GraphQLArgument(
                    type: GraphQLBoolean,
                    defaultValue: false
                )
            ],
            resolve: { type, arguments, _, _ -> [GraphQLFieldDefinition]? in
                if let type = type as? GraphQLObjectType {
                    let fieldMap = type.fields
                    var fields = Array(fieldMap.values).sorted(by: { $0.name < $1.name })

                    if !(arguments["includeDeprecated"].bool ?? false) {
                        fields = fields.filter({ !$0.isDeprecated })
                    }

                    return fields
                }

                if let type = type as? GraphQLInterfaceType {
                    let fieldMap = type.fields
                    var fields = Array(fieldMap.values).sorted(by: { $0.name < $1.name })

                    if !(arguments["includeDeprecated"].bool ?? false) {
                        fields = fields.filter({ !$0.isDeprecated })
                    }

                    return fields
                }

                return nil
            }
        ),
        "interfaces": GraphQLField(
            type: GraphQLList(GraphQLNonNull(GraphQLTypeReference("__Type"))),
            resolve: { type, _, _, _ -> [GraphQLInterfaceType]? in
                guard let type = type as? GraphQLObjectType else {
                    return nil
                }
                
                return type.interfaces
            }
        ),
        "possibleTypes": GraphQLField(
            type: GraphQLList(GraphQLNonNull(GraphQLTypeReference("__Type"))),
            resolve: { type, args, _, info -> [GraphQLObjectType]? in
                guard let type = type as? GraphQLAbstractType else {
                    return nil
                }

                return info.schema.getPossibleTypes(abstractType: type)
            }
        ),
        "enumValues": GraphQLField(
            type: GraphQLList(GraphQLNonNull(__EnumValue)),
            args: [
                "includeDeprecated": GraphQLArgument(
                    type: GraphQLBoolean,
                    defaultValue: false
                )
            ],
            resolve: { type, arguments, _, _ -> [GraphQLEnumValueDefinition]? in
                guard let type = type as? GraphQLEnumType else {
                    return nil
                }

                var values = type.values

                if !(arguments["includeDeprecated"].bool ?? false) {
                    values = values.filter({ !$0.isDeprecated })
                }

                return values
            }
        ),
        "inputFields": GraphQLField(
            type: GraphQLList(GraphQLNonNull(__InputValue)),
            resolve: { type, _, _, _ -> [InputObjectFieldDefinition]? in
                guard let type = type as? GraphQLInputObjectType else {
                    return nil
                }
                
                let fieldMap = type.fields
                let fields = Array(fieldMap.values).sorted(by: { $0.name < $1.name })
                return fields
            }
        ),
        "ofType": GraphQLField(type: GraphQLTypeReference("__Type"))
    ]
)

let __Field = try! GraphQLObjectType(
    name: "__Field",
    description:
    "Object and Interface types are described by a list of Fields, each of " +
    "which has a name, potentially a list of arguments, and a return type.",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "description": GraphQLField(type: GraphQLString),
        "args": GraphQLField(
            type: GraphQLNonNull(GraphQLList(GraphQLNonNull(__InputValue))),
            resolve: { field, _, _, _ -> [GraphQLArgumentDefinition]? in
                guard let field = field as? GraphQLFieldDefinition else {
                    return nil
                }

                return field.args
            }
        ),
        "type": GraphQLField(type: GraphQLNonNull(GraphQLTypeReference("__Type"))),
        "isDeprecated": GraphQLField(type: GraphQLNonNull(GraphQLBoolean)),
        "deprecationReason": GraphQLField(type: GraphQLString)
    ]
)

let __InputValue = try! GraphQLObjectType(
    name: "__InputValue",
    description:
    "Arguments provided to Fields or Directives and the input fields of an " +
    "InputObject are represented as Input Values which describe their type " +
    "and optionally a default value.",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "description": GraphQLField(type: GraphQLString),
        "type": GraphQLField(type: GraphQLNonNull(GraphQLTypeReference("__Type"))),
        "defaultValue": GraphQLField(
            type: GraphQLString,
            description:
            "A GraphQL-formatted string representing the default value for this " +
            "input value.",
            resolve: { inputValue, _, _, _ -> Map? in
                guard
                    let inputValue = inputValue as? GraphQLArgumentDefinition,
                    let defaultValue = inputValue.defaultValue
                else {
                    return nil
                }

                // This `print` is from the AST printer implementation
                return try astFromValue(value: defaultValue, type: inputValue.type).map { .string($0.encode()) }
            }
        )
    ]
)

extension Map {

    fileprivate func encodeAsGraphQLString() -> String {
        switch self {
        case .null:
            return "null"
        case .bool(let bool):
            return String(bool)
        case .number(let number):
            return number.stringValue
        case .string(let string):
            return "\"\(string)\""
        case .array(let array):
            let joined = array.map({ $0.encodeAsGraphQLString() }).joined(separator: ", ")
            return "[\(joined)]"
        case .dictionary(let dictionary):
            let joined = dictionary.map { "\($0.key) : \($0.value.encodeAsGraphQLString())" }.joined(separator: ", ")
            return "{\(joined)}"
        }
    }

}

let __EnumValue = try! GraphQLObjectType(
    name: "__EnumValue",
    description:
    "One possible value for a given Enum. Enum values are unique values, not " +
    "a placeholder for a string or numeric value. However an Enum value is " +
    "returned in a JSON response as a string.",
    fields: [
        "name": GraphQLField(type: GraphQLNonNull(GraphQLString)),
        "description": GraphQLField(type: GraphQLString),
        "isDeprecated": GraphQLField(type: GraphQLNonNull(GraphQLBoolean)),
        "deprecationReason": GraphQLField(type: GraphQLString)
    ]
)

public enum TypeKind : String, Encodable {
    case scalar = "SCALAR"
    case object = "OBJECT"
    case interface = "INTERFACE"
    case union = "UNION"
    case `enum` = "ENUM"
    case inputObject = "INPUT_OBJECT"
    case list = "LIST"
    case nonNull = "NON_NULL"
    case typeReference = "TYPE_REFERENCE"
}

let __TypeKind = try! GraphQLEnumType(
    name: "__TypeKind",
    description: "An enum describing what kind of type a given `__Type` is.",
    values: [
        "SCALAR": GraphQLEnumValue(
            value: Map(TypeKind.scalar.rawValue),
            description: "Indicates this type is a scalar."
        ),
        "OBJECT": GraphQLEnumValue(
            value: Map(TypeKind.object.rawValue),
            description: "Indicates this type is an object. " +
            "`fields` and `interfaces` are valid fields."
        ),
        "INTERFACE": GraphQLEnumValue(
            value: Map(TypeKind.interface.rawValue),
            description: "Indicates this type is an interface. " +
            "`fields` and `possibleTypes` are valid fields."
        ),
        "UNION": GraphQLEnumValue(
            value: Map(TypeKind.union.rawValue),
            description: "Indicates this type is a union. " +
            "`possibleTypes` is a valid field."
        ),
        "ENUM": GraphQLEnumValue(
            value: Map(TypeKind.enum.rawValue),
            description: "Indicates this type is an enum. " +
            "`enumValues` is a valid field."
        ),
        "INPUT_OBJECT": GraphQLEnumValue(
            value: Map(TypeKind.inputObject.rawValue),
            description: "Indicates this type is an input object. " +
            "`inputFields` is a valid field."
        ),
        "LIST": GraphQLEnumValue(
            value: Map(TypeKind.list.rawValue),
            description: "Indicates this type is a list. " +
            "`ofType` is a valid field."
        ),
        "NON_NULL": GraphQLEnumValue(
            value: Map(TypeKind.nonNull.rawValue),
            description: "Indicates this type is a non-null. " +
            "`ofType` is a valid field."
        ),
    ]
)

/**
 * Note that these are GraphQLFieldDefinition and not GraphQLField,
 * so the format for args is different.
 */

let SchemaMetaFieldDef = GraphQLFieldDefinition(
    name: "__schema",
    type: GraphQLNonNull(__Schema),
    description: "Access the current type schema of this server.",
    resolve: { _, _, _, eventLoopGroup, info in
        return eventLoopGroup.next().makeSucceededFuture(info.schema)
    }
)

let TypeMetaFieldDef = GraphQLFieldDefinition(
    name: "__type",
    type: __Type,
    description: "Request the type information of a single type.",
    args: [
        GraphQLArgumentDefinition(
            name: "name",
            type: GraphQLNonNull(GraphQLString)
        )
    ],
    resolve: { _, arguments, _, eventLoopGroup, info in
        let name = arguments["name"].string!
        return eventLoopGroup.next().makeSucceededFuture(info.schema.getType(name: name))
    }
)

let TypeNameMetaFieldDef = GraphQLFieldDefinition(
    name: "__typename",
    type: GraphQLNonNull(GraphQLString),
    description: "The name of the current Object type at runtime.",
    resolve: { _, _, _, eventLoopGroup, info in
        eventLoopGroup.next().makeSucceededFuture(info.parentType.name)
    }
)
