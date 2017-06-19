public enum DirectiveLocation : String {
    // Operations
    case query = "QUERY"
    case mutation = "MUTATION"
    case subscription = "SUBSCRIPTION"
    case field = "FIELD"
    case fragmentDefinition = "FRAGMENT_DEFINITION"
    case fragmentSpread = "FRAGMENT_SPREAD"
    case inlineFragment = "INLINE_FRAGMENT"
    // Schema Definitions
    case schema = "SCHEMA"
    case scalar = "SCALAR"
    case object = "OBJECT"
    case fieldDefinition = "FIELD_DEFINITION"
    case argumentDefinition = "ARGUMENT_DEFINITION"
    case interface = "INTERFACE"
    case union = "UNION"
    case `enum` = "ENUM"
    case enumValue = "ENUM_VALUE"
    case inputObject = "INPUT_OBJECT"
    case inputFieldDefinition = "INPUT_FIELD_DEFINITION"
}

extension DirectiveLocation : MapRepresentable {
    public var map: Map {
        return rawValue.map
    }
}

/**
 * Directives are used by the GraphQL runtime as a way of modifying execution
 * behavior. Type system creators will usually not create these directly.
 */
public struct GraphQLDirective {
    public let name: String
    public let description: String
    public let locations: [DirectiveLocation]
    public let args: [GraphQLArgumentDefinition]

    public init(
        name: String,
        description: String,
        locations: [DirectiveLocation],
        args: GraphQLArgumentConfigMap = [:]
    ) throws {
        try assertValid(name: name)
        self.name = name
        self.description = description
        self.locations = locations
        self.args = try defineArgumentMap(args: args)
    }
}

extension GraphQLDirective : MapRepresentable {
    public var map: Map {
        return [
            "name": name.map,
            "description": description.map,
            "locations": locations.map,
            "arg": args.map,
        ]
    }
}

/**
 * Used to conditionally include fields or fragments.
 */
public let GraphQLIncludeDirective = try! GraphQLDirective(
    name: "include",
    description:
    "Directs the executor to include this field or fragment only when " +
    "the `if` argument is true.",
    locations: [
        .field,
        .fragmentSpread,
        .inlineFragment,
    ],
    args: [
        "if": GraphQLArgument(
            type: GraphQLNonNull(GraphQLBoolean),
            description: "Included when true."
        )
    ]
)

/**
 * Used to conditionally skip (exclude) fields or fragments.
 */
public let GraphQLSkipDirective = try! GraphQLDirective(
    name: "skip",
    description:
    "Directs the executor to skip this field or fragment when the `if` " +
    "argument is true.",
    locations: [
        .field,
        .fragmentSpread,
        .inlineFragment,
    ],
    args: [
        "if": GraphQLArgument(
            type: GraphQLNonNull(GraphQLBoolean),
            description: "Skipped when true."
        )
    ]
)

/**
 * Constant string used for default reason for a deprecation.
 */
let defaulDeprecationReason: Map = .string("\"No longer supported\"")

/**
 * Used to declare element of a GraphQL schema as deprecated.
 */
public let GraphQLDeprecatedDirective = try! GraphQLDirective(
    name: "deprecated",
    description:
    "Marks an element of a GraphQL schema as no longer supported.",
    locations: [
        .fieldDefinition,
        .enumValue,
        ],
    args: [
        "if": GraphQLArgument(
            type: GraphQLNonNull(GraphQLBoolean),
            description:
            "Explains why this element was deprecated, usually also including a " +
            "suggestion for how to access supported similar data. Formatted " +
            "in [Markdown](https://daringfireball.net/projects/markdown/).",
            defaultValue: defaulDeprecationReason
        )
    ]
)

/**
 * The full list of specified directives.
 */
let specifiedDirectives: [GraphQLDirective] = [
    GraphQLIncludeDirective,
    GraphQLSkipDirective,
    GraphQLDeprecatedDirective,
]
