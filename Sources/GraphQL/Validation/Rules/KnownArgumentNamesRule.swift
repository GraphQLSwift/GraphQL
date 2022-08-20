import Foundation

func undefinedArgumentMessage(
    fieldName: String,
    type: String,
    argumentName: String,
    suggestedArgumentNames: [String]
) -> String {
    var message =
        "Field \"\(fieldName)\" on type \"\(type)\" does not have argument \"\(argumentName)\"."

    if !suggestedArgumentNames.isEmpty {
        let suggestions = quotedOrList(items: suggestedArgumentNames)
        message += " Did you mean \(suggestions)?"
    }

    return message
}

func KnownArgumentNamesRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if
                let node = node as? Argument, context.argument == nil, let field = context.fieldDef,
                let type = context.parentType
            {
                let argumentName = node.name.value
                let suggestedArgumentNames = getSuggestedArgumentNames(
                    schema: context.schema,
                    field: field,
                    argumentName: argumentName
                )

                context.report(error: GraphQLError(
                    message: undefinedArgumentMessage(
                        fieldName: field.name,
                        type: type.name,
                        argumentName: argumentName,
                        suggestedArgumentNames: suggestedArgumentNames
                    ),
                    nodes: [node]
                ))
            }

            return .continue
        }
    )
}

func getSuggestedArgumentNames(
    schema _: GraphQLSchema,
    field: GraphQLFieldDefinition,
    argumentName: String
) -> [String] {
    return suggestionList(
        input: argumentName,
        options: field.args.map { $0.name }
    )
}
