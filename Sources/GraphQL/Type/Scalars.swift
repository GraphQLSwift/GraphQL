public let GraphQLInt = try! GraphQLScalarType(
    name: "Int",
    description:
    "The `Int` scalar type represents non-fractional signed whole numeric " +
    "values. Int can represent values between -(2^31) and 2^31 - 1.",
    serialize: { try $0.map.asInt(converting: true) } ,
    parseValue: { try $0.map.asInt(converting: true) },
    parseLiteral: { ast in
        if let ast = ast as? IntValue, let int = Int(ast.value) {
            return int
        }
        
        return Map.null
    }
)

public let GraphQLFloat = try! GraphQLScalarType(
    name: "Float",
    description:
    "The `Float` scalar type represents signed double-precision fractional " +
    "values as specified by " +
    "[IEEE 754](http://en.wikipedia.org/wiki/IEEE_floating_point). ",
    serialize: { try $0.map.asDouble(converting: true) } ,
    parseValue: { try $0.map.asDouble(converting: true) },
    parseLiteral: { ast in
        if let ast = ast as? FloatValue, let double = Double(ast.value) {
            return double
        }

        if let ast = ast as? IntValue, let double = Double(ast.value) {
            return double
        }

        return Map.null
    }
)

public let GraphQLString = try! GraphQLScalarType(
    name: "String",
    description:
    "The `String` scalar type represents textual data, represented as UTF-8 " +
    "character sequences. The String type is most often used by GraphQL to " +
    "represent free-form human-readable text.",
    serialize: { try $0.map.asString(converting: true) } ,
    parseValue: { try $0.map.asString(converting: true) },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return ast.value
        }

        return Map.null
    }
)

public let GraphQLBoolean = try! GraphQLScalarType(
    name: "Boolean",
    description: "The `Boolean` scalar type represents `true` or `false`.",
    serialize: { try $0.map.asBool(converting: true) } ,
    parseValue: { try $0.map.asBool(converting: true) },
    parseLiteral: { ast in
        if let ast = ast as? BooleanValue {
            return ast.value
        }

        return Map.null
    }
)

public let GraphQLID = try! GraphQLScalarType(
    name: "ID",
    description:
    "The `ID` scalar type represents a unique identifier, often used to " +
    "refetch an object or as key for a cache. The ID type appears in a JSON " +
    "response as a String; however, it is not intended to be human-readable. " +
    "When expected as an input type, any string (such as `\"4\"`) or integer " +
    "(such as `4`) input value will be accepted as an ID.",
    serialize: { try $0.map.asString(converting: true) },
    parseValue: { try $0.map.asString(converting: true) },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return ast.value
        }

        if let ast = ast as? IntValue {
            return ast.value
        }

        return Map.null
    }
)
