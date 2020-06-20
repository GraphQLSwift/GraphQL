import Foundation

func missingArgumentsMessage(
    fieldName: String,
    type: String,
    missingArguments: [String]
) -> String {
    let arguments = quotedOrList(items: missingArguments)
    return "Field \"\(fieldName)\" on type \"\(type)\" is missing required arguments \(arguments)."
}

 func ProvidedNonNullArgumentsRule(context: ValidationContext) -> Visitor {
    return Visitor(
        leave: { node, key, parent, path, ancestors in
            if let node = node as? Field, let field = context.fieldDef, let type = context.parentType {
                let requiredArguments = Set(
                    field
                        .args
                        .filter { $0.type is GraphQLNonNull && $0.defaultValue == nil }
                        .map { $0.name }
                )

                 let providedArguments = Set(node.arguments.map { $0.name.value })

                 let missingArguments = requiredArguments.subtracting(providedArguments)
                if !missingArguments.isEmpty {
                    context.report(error: GraphQLError(
                        message: missingArgumentsMessage(
                            fieldName: field.name,
                            type: type.name,
                            missingArguments: Array(missingArguments)
                        ),
                        nodes: [node]
                    ))
                }
            }

             return .continue
        }
    )
}
