public let GraphQLString = try! GraphQLScalarType(
    name: "String",
    description:
    "The `String` scalar type represents textual data, represented as UTF-8 " +
        "character sequences. The String type is most often used by GraphQL to " +
    "represent free-form human-readable text.",
    serialize: { try Map($0.asString(converting: true)) } ,
    parseValue: { try Map($0.asString(converting: true)) },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return .string(ast.value)
        }
        return nil
    }
)

public let GraphQLInt = try! GraphQLScalarType(
    name: "String",
    description:
    "The `String` scalar type represents textual data, represented as UTF-8 " +
        "character sequences. The String type is most often used by GraphQL to " +
    "represent free-form human-readable text.",
    serialize: { try Map($0.asString(converting: true)) } ,
    parseValue: { try Map($0.asString(converting: true)) },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return .string(ast.value)
        }
        return nil
    }
)

public let GraphQLBoolean = try! GraphQLScalarType(
    name: "String",
    description:
    "The `String` scalar type represents textual data, represented as UTF-8 " +
        "character sequences. The String type is most often used by GraphQL to " +
    "represent free-form human-readable text.",
    serialize: { try Map($0.asString(converting: true)) } ,
    parseValue: { try Map($0.asString(converting: true)) },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return .string(ast.value)
        }
        return nil
    }
)
