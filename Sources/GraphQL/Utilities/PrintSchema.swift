import Foundation

public func printSchema(schema: GraphQLSchema) -> String {
    return printFilteredSchema(
        schema: schema,
        directiveFilter: { n in !isSpecifiedDirective(n) },
        typeFilter: isDefinedType
    )
}

public func printIntrospectionSchema(schema: GraphQLSchema) -> String {
    return printFilteredSchema(
        schema: schema,
        directiveFilter: isSpecifiedDirective,
        typeFilter: isIntrospectionType
    )
}

func isDefinedType(type: GraphQLNamedType) -> Bool {
    return !isSpecifiedScalarType(type) && !isIntrospectionType(type: type)
}

func printFilteredSchema(
    schema: GraphQLSchema,
    directiveFilter: (GraphQLDirective) -> Bool,
    typeFilter: (GraphQLNamedType) -> Bool
) -> String {
    let directives = schema.directives.filter { directiveFilter($0) }
    let types = schema.typeMap.values.filter { typeFilter($0) }

    var result = [printSchemaDefinition(schema: schema)]
    result.append(contentsOf: directives.map { printDirective(directive: $0) })
    result.append(contentsOf: types.map { printType(type: $0) })

    return result.compactMap { $0 }
        .joined(separator: "\n\n")
}

func printSchemaDefinition(schema: GraphQLSchema) -> String? {
    let queryType = schema.queryType
    let mutationType = schema.mutationType
    let subscriptionType = schema.subscriptionType

    // Special case: When a schema has no root operation types, no valid schema
    // definition can be printed.
    if queryType == nil, mutationType == nil, subscriptionType == nil {
        return nil
    }

    // Only print a schema definition if there is a description or if it should
    // not be omitted because of having default type names.
    if schema.description != nil || !hasDefaultRootOperationTypes(schema: schema) {
        var result = printDescription(schema.description) +
            "schema {\n"
        if let queryType = queryType {
            result = result + "  query: \(queryType.name)\n"
        }
        if let mutationType = mutationType {
            result = result + "  mutation: \(mutationType.name)\n"
        }
        if let subscriptionType = subscriptionType {
            result = result + "  subscription: \(subscriptionType.name)\n"
        }
        result = result + "}"
        return result
    }
    return nil
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
 * When using this naming convention, the schema description can be omitted so
 * long as these names are only used for operation types.
 *
 * Note however that if any of these default names are used elsewhere in the
 * schema but not as a root operation type, the schema definition must still
 * be printed to avoid ambiguity.
 */
func hasDefaultRootOperationTypes(schema: GraphQLSchema) -> Bool {
    // The goal here is to check if a type was declared using the default names of "Query",
    // "Mutation" or "Subscription". We do so by comparing object IDs to determine if the
    // schema operation object is the same as the type object by that name.
    return (
        schema.queryType.map { ObjectIdentifier($0) }
            == (schema.getType(name: "Query") as? GraphQLObjectType).map { ObjectIdentifier($0) } &&
            schema.mutationType.map { ObjectIdentifier($0) }
            == (schema.getType(name: "Mutation") as? GraphQLObjectType)
            .map { ObjectIdentifier($0) } &&
            schema.subscriptionType.map { ObjectIdentifier($0) }
            == (schema.getType(name: "Subscription") as? GraphQLObjectType)
            .map { ObjectIdentifier($0) }
    )
}

public func printType(type: GraphQLNamedType) -> String {
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

    // Not reachable, all possible types have been considered.
    fatalError("Unexpected type: " + type.name)
}

func printScalar(type: GraphQLScalarType) -> String {
    return printDescription(type.description) +
        "scalar \(type.name)" +
        printSpecifiedByURL(scalar: type)
}

func printImplementedInterfaces(
    interfaces: [GraphQLInterfaceType]
) -> String {
    return interfaces.isEmpty
        ? ""
        : " implements " + interfaces.map { $0.name }.joined(separator: " & ")
}

func printObject(type: GraphQLObjectType) -> String {
    return
        printDescription(type.description) +
        "type \(type.name)" +
        printImplementedInterfaces(interfaces: (try? type.getInterfaces()) ?? []) +
        printFields(fields: (try? type.getFields()) ?? [:])
}

func printInterface(type: GraphQLInterfaceType) -> String {
    return
        printDescription(type.description) +
        "interface \(type.name)" +
        printImplementedInterfaces(interfaces: (try? type.getInterfaces()) ?? []) +
        printFields(fields: (try? type.getFields()) ?? [:])
}

func printUnion(type: GraphQLUnionType) -> String {
    let types = (try? type.getTypes()) ?? []
    return
        printDescription(type.description) +
        "union \(type.name)" +
        (types.isEmpty ? "" : " = " + types.map { $0.name }.joined(separator: " | "))
}

func printEnum(type: GraphQLEnumType) -> String {
    let values = type.values.enumerated().map { i, value in
        printDescription(value.description, indentation: "  ", firstInBlock: i == 0) +
            "  " +
            value.name +
            printDeprecated(reason: value.deprecationReason)
    }

    return printDescription(type.description) + "enum \(type.name)" + printBlock(items: values)
}

func printInputObject(type: GraphQLInputObjectType) -> String {
    let inputFields = (try? type.getFields()) ?? [:]
    let fields = inputFields.values.enumerated().map { i, f in
        printDescription(f.description, indentation: "  ", firstInBlock: i == 0) + "  " +
            printInputValue(arg: f)
    }

    return
        printDescription(type.description) +
        "input \(type.name)" +
        (type.isOneOf ? " @oneOf" : "") +
        printBlock(items: fields)
}

func printFields(fields: GraphQLFieldDefinitionMap) -> String {
    let fields = fields.values.enumerated().map { i, f in
        printDescription(f.description, indentation: "  ", firstInBlock: i == 0) +
            "  " +
            f.name +
            printArgs(args: f.args, indentation: "  ") +
            ": " +
            f.type.debugDescription +
            printDeprecated(reason: f.deprecationReason)
    }
    return printBlock(items: fields)
}

func printBlock(items: [String]) -> String {
    return items.isEmpty ? "" : " {\n" + items.joined(separator: "\n") + "\n}"
}

func printArgs(
    args: [GraphQLArgumentDefinition],
    indentation: String = ""
) -> String {
    if args.isEmpty {
        return ""
    }

    // If every arg does not have a description, print them on one line.
    if args.allSatisfy({ $0.description == nil }) {
        return "(" + args.map { printArgValue(arg: $0) }.joined(separator: ", ") + ")"
    }

    return
        "(\n" +
        args.enumerated().map { i, arg in
            printDescription(
                arg.description,
                indentation: "  " + indentation,
                firstInBlock: i == 0
            ) +
                "  " +
                indentation +
                printArgValue(arg: arg)
        }.joined(separator: "\n") +
        "\n" +
        indentation +
        ")"
}

func printArgValue(arg: GraphQLArgumentDefinition) -> String {
    var argDecl = arg.name + ": " + arg.type.debugDescription
    if let defaultValue = arg.defaultValue {
        if defaultValue == .null {
            argDecl = argDecl + " = null"
        } else if let defaultAST = try! astFromValue(value: defaultValue, type: arg.type) {
            argDecl = argDecl + " = \(print(ast: defaultAST))"
        }
    }
    return argDecl + printDeprecated(reason: arg.deprecationReason)
}

func printInputValue(arg: InputObjectFieldDefinition) -> String {
    var argDecl = arg.name + ": " + arg.type.debugDescription
    if let defaultAST = try? astFromValue(value: arg.defaultValue ?? .null, type: arg.type) {
        argDecl = argDecl + " = \(print(ast: defaultAST))"
    }
    return argDecl + printDeprecated(reason: arg.deprecationReason)
}

public func printDirective(directive: GraphQLDirective) -> String {
    return
        printDescription(directive.description) +
        "directive @" +
        directive.name +
        printArgs(args: directive.args) +
        (directive.isRepeatable ? " repeatable" : "") +
        " on " +
        directive.locations.map { $0.rawValue }.joined(separator: " | ")
}

func printDeprecated(reason: String?) -> String {
    guard let reason = reason else {
        return ""
    }
    if reason != defaultDeprecationReason {
        let astValue = print(ast: StringValue(value: reason))
        return " @deprecated(reason: \(astValue))"
    }
    return " @deprecated"
}

func printSpecifiedByURL(scalar: GraphQLScalarType) -> String {
    guard let specifiedByURL = scalar.specifiedByURL else {
        return ""
    }
    let astValue = StringValue(value: specifiedByURL)
    return " @specifiedBy(url: \"\(astValue.value)\")"
}

func printDescription(
    _ description: String?,
    indentation: String = "",
    firstInBlock: Bool = true
) -> String {
    guard let description = description else {
        return ""
    }

    let blockString = print(ast: StringValue(
        value: description,
        block: isPrintableAsBlockString(description)
    ))

    let prefix = (!indentation.isEmpty && !firstInBlock) ? "\n" + indentation : indentation

    return prefix + blockString.replacingOccurrences(of: "\n", with: "\n" + indentation) + "\n"
}
