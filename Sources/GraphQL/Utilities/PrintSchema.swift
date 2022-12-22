public func printSchema(schema: GraphQLSchema) -> String {
    printFilteredSchema(
        schema: schema,
        directiveFilter: { !isSpecifiedDirective($0) },
        typeFilter: isDefinedType
    )
}

public func printIntrospectionSchema(schema: GraphQLSchema) -> String {
    printFilteredSchema(
        schema: schema,
        directiveFilter: isSpecifiedDirective,
        typeFilter: isIntrospectionType
    )
}

func isDefinedType(_ type: GraphQLNamedType) -> Bool {
    !isSpecifiedScalarType(type: type) && !isIntrospectionType(type: type)
}

func printFilteredSchema(
    schema: GraphQLSchema,
    directiveFilter: (_ type: GraphQLDirective) -> Bool,
    typeFilter: (_ type: GraphQLNamedType) -> Bool
) -> String {
    let directives = schema.directives.filter(directiveFilter)
    let types = schema.typeMap.values.filter(typeFilter)

    return (
        [printSchemaDefinition(schema: schema)].compactMap { $0 } +
            directives.map(printDirective) +
            types.map(printType)
    )
    .joined(separator: "\n\n")
}

func printSchemaDefinition(schema: GraphQLSchema) -> String? {
    #warning("TODO: Implement schema description")
    if /* schema.description == nil && */ isSchemaOfCommonNames(schema: schema) {
        return nil
    }

    var operationTypes: [String] = []

    let queryType = schema.queryType
    operationTypes.append("  query: \(queryType.name)")

    if let mutationType = schema.mutationType {
        operationTypes.append("  mutation: \(mutationType.name)")
    }

    if let subscriptionType = schema.subscriptionType {
        operationTypes.append("  subscription: \(subscriptionType.name)")
    }

    #warning("TODO: Implement schema description")
    return
//        printDescription(description: schema.description) +
        "schema {\n\(operationTypes.joined(separator: "\n"))\n}"
}

/**
 * GraphQL schema define root types for each type of operation. These types are
 * the same as any other type and can be named in any manner, however there is
 * a common naming convention:
 *
 * ```graphql
 *   schema {
 *     query: Query
 *     mutation: Mutation
 *     subscription: Subscription
 *   }
 * ```
 *
 * When using this naming convention, the schema definition can be omitted.
 */
func isSchemaOfCommonNames(schema: GraphQLSchema) -> Bool {
    if schema.queryType.name != "Query" {
        return false
    }

    if let mutationType = schema.mutationType, mutationType.name != "Mutation" {
        return false
    }

    if let subscriptionType = schema.subscriptionType, subscriptionType.name != "Subscription" {
        return false
    }

    return true
}

func printType(type: GraphQLNamedType) -> String {
    if let type = type as? GraphQLScalarType {
        return printScalar(type: type)
    }

    if let type = type as? GraphQLObjectType {
        return printObject(type: type)
    }

    if let type = type as? GraphQLInterfaceType {
        return printInterface(type: type)
    }

    if let type = type as? GraphQLUnionType {
        return printUnion(type: type)
    }

    if let type = type as? GraphQLEnumType {
        return printEnum(type: type)
    }

    if let type = type as? GraphQLInputObjectType {
        return printInputObject(type: type)
    }

    fatalError("Unexpected type: \(Swift.type(of: type))")
}

func printScalar(type: GraphQLScalarType) -> String {
    printDescription(description: type.description) +
        "scalar \(type.name)" +
        printSpecifiedByURL(scalar: type)
}

protocol InterfaceType {
    var interfaces: [GraphQLInterfaceType] { get }
}

extension GraphQLObjectType: InterfaceType {}
extension GraphQLInterfaceType: InterfaceType {}

func printImplementedInterfaces(
    type: InterfaceType // GraphQLObjectType | GraphQLInterfaceType
) -> String {
    let interfaces = type.interfaces

    return !interfaces.isEmpty
        ? " implements " + interfaces.map(\.name).joined(separator: " & ")
        : ""
}

func printObject(type: GraphQLObjectType) -> String {
    printDescription(description: type.description) +
        "type \(type.name)" +
        printImplementedInterfaces(type: type) +
        printFields(type: type)
}

func printInterface(type: GraphQLInterfaceType) -> String {
    printDescription(description: type.description) +
        "interface \(type.name)" +
        printImplementedInterfaces(type: type) +
        printFields(type: type)
}

func printUnion(type: GraphQLUnionType) -> String {
    let types = type.types
    let possibleTypes = !types.isEmpty ? " = " + types.map(\.name).joined(separator: " | ") : ""

    return
        printDescription(description: type.description) +
        "union " +
        type.name +
        possibleTypes
}

func printEnum(type: GraphQLEnumType) -> String {
    let values = type.values.enumerated().map { index, value in
        printDescription(
            description: value.description,
            indentation: "  ",
            firstInBlock: index == 0
        ) +
            "  " +
            value.name +
            printDeprecated(reason: value.deprecationReason)
    }

    return printDescription(description: type.description) + "enum \(type.name)" +
        printBlock(items: values)
}

func printInputObject(type: GraphQLInputObjectType) -> String {
    let fields = type.fields.values.enumerated().map { index, field in
        printDescription(
            description: field.description,
            indentation: "  ",
            firstInBlock: index == 0
        ) +
            "  " +
            printInputValue(arg: field)
    }

    return
        printDescription(description: type.description) +
        "input \(type.name)" +
        printBlock(items: fields)
}

protocol FieldType {
    var fields: GraphQLFieldDefinitionMap { get }
}

extension GraphQLObjectType: FieldType {}
extension GraphQLInterfaceType: FieldType {}

func printFields(
    type: FieldType // GraphQLObjectType | GraphQLInterfaceType
) -> String {
    let fields = type.fields.values.enumerated().map { index, field in
        printDescription(
            description: field.description,
            indentation: "  ",
            firstInBlock: index == 0
        ) +
            "  " +
            field.name +
            printArgs(args: field.args, indentation: "  ") +
            ": " +
            "\(field.type)" +
            printDeprecated(reason: field.deprecationReason)
    }

    return printBlock(items: fields)
}

func printBlock(items: [String]) -> String {
    !items.isEmpty ? " {\n" + items.joined(separator: "\n") + "\n}" : ""
}

func printArgs(
    args: [GraphQLArgumentDefinition], // [GraphQLArgument]
    indentation: String = ""
) -> String {
    guard !args.isEmpty else {
        return ""
    }

    // If every arg does not have a description, print them on one line.
    if args.allSatisfy({ $0.description == nil }) {
        return "(" + args.map(printInputValue).joined(separator: ", ") + ")"
    }

    return
        "(\n" +
        args
        .enumerated()
        .map { index, arg in
            printDescription(
                description: arg.description,
                indentation: "  " + indentation,
                firstInBlock: index == 0
            ) +
                "  " +
                indentation +
                printInputValue(arg: arg)
        }
        .joined(separator: "\n") +
        "\n" +
        indentation +
        ")"
}

extension InputObjectFieldDefinition: GraphQLInputField {}
extension GraphQLArgumentDefinition: GraphQLInputField {}

func printInputValue(arg: GraphQLInputField) -> String {
    let defaultAST = try? astFromValue(value: arg.defaultValue ?? .null, type: arg.type)
    var argDecl = arg.name + ": " + "\(arg.type)"

    if let defaultAST = defaultAST {
        #warning("TODO: Implement print(ast:)")
        argDecl += " = \(printValue(value: defaultAST))"
    }

    #warning("TODO: Implement argument deprecation")
    return argDecl // + printDeprecated(reason: arg.deprecationReason)
}

func printValue(value: Any) -> String {
    if let variable = value as? Variable {
        return "$" + variable.name.value
    }

    if let int = value as? IntValue {
        return int.value
    }

    if let float = value as? FloatValue {
        return float.value
    }

    if let string = value as? StringValue {
        return printString(string: string.value)
    }

    if let boolean = value as? BooleanValue {
        return boolean.value ? "true" : "false"
    }

    if value is NullValue {
        return "null"
    }

    if let enumValue = value as? EnumValue {
        return enumValue.value
    }

    if let list = value as? ListValue {
        return "[" + list.values.map(printValue).joined(separator: ", ") + "]"
    }

    if let object = value as? ObjectValue {
        return "[" + object.fields.map(printValue).joined(separator: ", ") + "]"
    }

    if let field = value as? ObjectField {
        return field.name.value + ": " + printValue(value: field.value)
    }

    fatalError("Unreachable")
}

#warning("TODO: Implement repeatable directives")
func printDirective(directive: GraphQLDirective) -> String {
    printDescription(description: directive.description) +
        "directive @" +
        directive.name +
        printArgs(args: directive.args) +
//    (directive.isRepeatable ? " repeatable" : "") +
        " on " +
        directive.locations.map(\.rawValue).joined(separator: " | ")
}

func printDeprecated(reason: String?) -> String {
    guard let reason = reason else {
        return ""
    }

    if reason != defaulDeprecationReason {
        #warning("TODO: Implement print(ast:)")
//        let astValue = print(ast: ASTValue(kind: Kind.STRING, value: reason))
        let astValue = printString(string: reason)
        return " @deprecated(reason: \(astValue))"
    }

    return " @deprecated'"
}

func printSpecifiedByURL(scalar: GraphQLScalarType) -> String {
    guard let specifiedByURL = scalar.specifiedByURL else {
        return ""
    }

    #warning("TODO: Implement print(ast:)")
//    let astValue = print(ast: StringValue(value: specifiedByURL))
    let astValue = printString(string: specifiedByURL)

    return " @specifiedBy(url: \(astValue)"
}

func printDescription(
    description: String?,
    indentation: String = "",
    firstInBlock: Bool = true
) -> String {
    guard let description = description else {
        return ""
    }

    let blockString = printBlockString(
        value: description,
        preferMultipleLines: description.count > 70
    )

    let prefix =
        !indentation.isEmpty && !firstInBlock ? "\n" + indentation : indentation

    return
        prefix +
        blockString.replacingOccurrences(of: "\n", with: "\n" + indentation) +
        "\n"
}
