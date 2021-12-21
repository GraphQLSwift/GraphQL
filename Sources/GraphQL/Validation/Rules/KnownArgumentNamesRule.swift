import Foundation

 func undefinedArgumentMessage(
    fieldName: String,
    type: String,
    argumentName: String,
    suggestedArgumentNames: [String]
) -> String {
    var message = "Field \"\(fieldName)\" on type \"\(type)\" does not have argument \"\(argumentName)\"."

     if !suggestedArgumentNames.isEmpty {
        let suggestions = quotedOrList(items: suggestedArgumentNames)
        message += " Did you mean \(suggestions)?"
    }

     return message
}

struct KnownArgumentNamesRule: ValidationRule {
    let context: ValidationContext
    func enter(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument> {
        if context.argument == nil, let field = context.fieldDef, let type = context.parentType {
            let argumentName = argument.name.value
            let suggestedArgumentNames = getSuggestedArgumentNames(schema: context.schema, field: field, argumentName: argumentName)
            
            context.report(error: GraphQLError(
                message: undefinedArgumentMessage(
                    fieldName: field.name,
                    type: type.name,
                    argumentName: argumentName,
                    suggestedArgumentNames: suggestedArgumentNames
                ),
                nodes: [argument]
            ))
        }
        return .continue
    }
}

 func getSuggestedArgumentNames(
    schema: GraphQLSchema,
    field: GraphQLFieldDefinition,
    argumentName: String
) -> [String] {
    return suggestionList(
        input: argumentName,
        options: field.args.map { $0.name }
    )
}
