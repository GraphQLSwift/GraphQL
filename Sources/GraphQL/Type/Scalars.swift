/**
 * Maximum possible Int value as per GraphQL Spec (32-bit signed integer).
 * n.b. This differs from JavaScript's numbers that are IEEE 754 doubles safe up-to 2^53 - 1
 * */
let GRAPHQL_MAX_INT = 2_147_483_647

/**
 * Minimum possible Int value as per GraphQL Spec (32-bit signed integer).
 * n.b. This differs from JavaScript's numbers that are IEEE 754 doubles safe starting at -(2^53 - 1)
 * */
let GRAPHQL_MIN_INT = -2_147_483_648

public let GraphQLInt = try! GraphQLScalarType(
    name: "Int",
    description:
    "The `Int` scalar type represents non-fractional signed whole numeric " +
        "values. Int can represent values between -(2^31) and 2^31 - 1.",
    serialize: { outputValue in
        if let value = outputValue as? Map {
            if case let .number(value) = value {
                return .int(value.intValue)
            }
            throw GraphQLError(
                message: "Float cannot represent non numeric value: \(value)"
            )
        }
        if let value = outputValue as? Bool {
            return value ? .int(1) : .int(0)
        }
        if let value = outputValue as? String, value != "", let int = Int(value) {
            return .int(int)
        }
        if
            let value = outputValue as? Double, Double(GRAPHQL_MIN_INT) <= value,
            value <= Double(GRAPHQL_MAX_INT), value.isFinite
        {
            return .int(Int(value))
        }
        if let value = outputValue as? Int, GRAPHQL_MIN_INT <= value, value <= GRAPHQL_MAX_INT {
            return .int(value)
        }
        throw GraphQLError(
            message: "Int cannot represent non-integer value: \(outputValue)"
        )
    },
    parseValue: { inputValue in
        if
            case let .number(value) = inputValue, Double(GRAPHQL_MIN_INT) <= value.doubleValue,
            value.doubleValue <= Double(GRAPHQL_MAX_INT), value.doubleValue.isFinite
        {
            return .number(value)
        }
        throw GraphQLError(
            message: "Int cannot represent non-integer value: \(inputValue)"
        )
    },
    parseLiteral: { ast in
        if let ast = ast as? IntValue, let int = Int(ast.value) {
            return .int(int)
        }

        throw GraphQLError(
            message: "Int cannot represent non-integer value: \(print(ast: ast))",
            nodes: [ast]
        )
    }
)

public let GraphQLFloat = try! GraphQLScalarType(
    name: "Float",
    description:
    "The `Float` scalar type represents signed double-precision fractional " +
        "values as specified by " +
        "[IEEE 754](http://en.wikipedia.org/wiki/IEEE_floating_point). ",
    serialize: { outputValue in
        if let value = outputValue as? Map {
            if case let .number(value) = value {
                return .double(value.doubleValue)
            }
            throw GraphQLError(
                message: "Float cannot represent non numeric value: \(value)"
            )
        }
        if let value = outputValue as? Bool {
            return value ? .double(1) : .double(0)
        }
        if let value = outputValue as? String, value != "", let double = Double(value) {
            return .double(double)
        }
        if let value = outputValue as? Double, value.isFinite {
            return .double(value)
        }
        if let value = outputValue as? Int {
            return .double(Double(value))
        }
        throw GraphQLError(
            message: "Float cannot represent non numeric value: \(outputValue)"
        )
    },
    parseValue: { inputValue in
        if case let .number(value) = inputValue, value.doubleValue.isFinite {
            return .number(value)
        }
        throw GraphQLError(
            message: "Float cannot represent non numeric value: \(inputValue)"
        )
    },
    parseLiteral: { ast in
        if let ast = ast as? FloatValue, let double = Double(ast.value) {
            return .double(double)
        }

        if let ast = ast as? IntValue, let double = Double(ast.value) {
            return .double(double)
        }

        throw GraphQLError(
            message: "Float cannot represent non-numeric value: \(print(ast: ast))",
            nodes: [ast]
        )
    }
)

public let GraphQLString = try! GraphQLScalarType(
    name: "String",
    description:
    "The `String` scalar type represents textual data, represented as UTF-8 " +
        "character sequences. The String type is most often used by GraphQL to " +
        "represent free-form human-readable text.",
    serialize: { outputValue in
        if let value = outputValue as? Map {
            if case let .string(value) = value {
                return .string(value)
            }
            throw GraphQLError(
                message: "String cannot represent a non string value: \(value)"
            )
        }
        if let value = outputValue as? String {
            return .string(value)
        }
        if let value = outputValue as? Bool {
            return value ? .string("true") : .string("false")
        }
        if let value = outputValue as? Int {
            return .string(value.description)
        }
        if let value = outputValue as? Double, value.isFinite {
            return .string(value.description)
        }
        throw GraphQLError(
            message: "String cannot represent value: \(outputValue)"
        )
    },
    parseValue: { outputValue in
        if case let .string(value) = outputValue {
            return .string(value)
        }
        throw GraphQLError(
            message: "String cannot represent a non string value: \(outputValue)"
        )
    },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return .string(ast.value)
        }

        throw GraphQLError(
            message: "String cannot represent a non-string value: \(print(ast: ast))",
            nodes: [ast]
        )
    }
)

public let GraphQLBoolean = try! GraphQLScalarType(
    name: "Boolean",
    description: "The `Boolean` scalar type represents `true` or `false`.",
    serialize: { outputValue in
        if let value = outputValue as? Map {
            if case let .bool(value) = value {
                return .bool(value)
            }
            if case let .number(value) = value {
                return .bool(value.intValue != 0)
            }
            throw GraphQLError(
                message: "Boolean cannot represent a non boolean value: \(value)"
            )
        }
        if let value = outputValue as? Bool {
            return .bool(value)
        }
        if let value = outputValue as? Int {
            return .bool(value != 0)
        }
        throw GraphQLError(
            message: "Boolean cannot represent a non boolean value: \(outputValue)"
        )
    },
    parseValue: { inputValue in
        if case let .bool(value) = inputValue {
            return inputValue
        }
        // NOTE: We deviate from graphql-js and allow numeric conversions here because
        // the MapCoder's round-trip conversion to NSObject for Bool converts to 0/1 numbers.
        if case let .number(value) = inputValue {
            return .bool(value.intValue != 0)
        }
        throw GraphQLError(
            message: "Boolean cannot represent a non boolean value: \(inputValue)"
        )
    },
    parseLiteral: { ast in
        if let ast = ast as? BooleanValue {
            return .bool(ast.value)
        }

        throw GraphQLError(
            message: "Boolean cannot represent a non-boolean value: \(print(ast: ast))",
            nodes: [ast]
        )
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
    serialize: { outputValue in
        if let value = outputValue as? Map {
            if case let .string(value) = value {
                return .string(value)
            }
            if case let .number(value) = value {
                return .string(value.description)
            }
            throw GraphQLError(
                message: "ID cannot represent value: \(value)"
            )
        }
        if let value = outputValue as? String {
            return .string(value)
        }
        if let value = outputValue as? Int {
            return .string(value.description)
        }
        throw GraphQLError(message: "ID cannot represent value: \(outputValue)")
    },
    parseValue: { inputValue in
        if case let .string(value) = inputValue {
            return inputValue
        }
        if case let .number(value) = inputValue, value.storageType == .int {
            return .string(value.description)
        }
        throw GraphQLError(message: "ID cannot represent value: \(inputValue)")
    },
    parseLiteral: { ast in
        if let ast = ast as? StringValue {
            return .string(ast.value)
        }

        if let ast = ast as? IntValue {
            return .string(ast.value)
        }

        throw GraphQLError(
            message: "ID cannot represent a non-string and non-integer value: \(print(ast: ast))",
            nodes: [ast]
        )
    }
)

let specifiedScalarTypes = [
    GraphQLString,
    GraphQLInt,
    GraphQLFloat,
    GraphQLBoolean,
    GraphQLID,
]

func isSpecifiedScalarType(_ type: GraphQLNamedType) -> Bool {
    return specifiedScalarTypes.contains { $0.name == type.name }
}
