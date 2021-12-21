import Foundation

func missingArgumentsMessage(
    fieldName: String,
    type: String,
    missingArguments: [String]
) -> String {
    let arguments = quotedOrList(items: missingArguments)
    return "Field \"\(fieldName)\" on type \"\(type)\" is missing required arguments \(arguments)."
}

struct ProvidedNonNullArgumentsRule: ValidationRule {
    let context: ValidationContext
    func leave(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
        if let fieldDef = context.fieldDef, let type = context.parentType {
            let requiredArguments = Set(
                fieldDef
                    .args
                    .filter { $0.type is GraphQLNonNull && $0.defaultValue == nil }
                    .map { $0.name }
            )
            
            let providedArguments = Set(field.arguments.map { $0.name.value })
            
            let missingArguments = requiredArguments.subtracting(providedArguments)
            if !missingArguments.isEmpty {
                context.report(error: GraphQLError(
                    message: missingArgumentsMessage(
                        fieldName: fieldDef.name,
                        type: type.name,
                        missingArguments: Array(missingArguments)
                    ),
                    nodes: [field]
                ))
            }
        }

        return .continue
    }
}
