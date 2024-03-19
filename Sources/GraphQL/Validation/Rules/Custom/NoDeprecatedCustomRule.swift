
/**
 * No deprecated
 *
 * A GraphQL document is only valid if all selected fields and all used enum values have not been
 * deprecated.
 *
 * Note: This rule is optional and is not part of the Validation section of the GraphQL
 * Specification. The main purpose of this rule is detection of deprecated usages and not
 * necessarily to forbid their use when querying a service.
 */
public func NoDeprecatedCustomRule(context: ValidationContext) -> Visitor {
    return Visitor(
        enter: { node, _, _, _, _ in
            if let node = node as? Field {
                if
                    let fieldDef = context.fieldDef,
                    let deprecationReason = fieldDef.deprecationReason,
                    let parentType = context.parentType
                {
                    context.report(
                        error: GraphQLError(
                            message: "The field \(parentType.name).\(fieldDef.name) is deprecated. \(deprecationReason)",
                            nodes: [node]
                        )
                    )
                }
            }
            if let node = node as? Argument {
                if
                    let argDef = context.argument,
                    let deprecationReason = argDef.deprecationReason
                {
                    if let directiveDef = context.typeInfo.directive {
                        context.report(
                            error: GraphQLError(
                                message: "Directive \"@\(directiveDef.name)\" argument \"\(argDef.name)\" is deprecated. \(deprecationReason)",
                                nodes: [node]
                            )
                        )
                    } else if
                        let fieldDef = context.fieldDef,
                        let parentType = context.parentType
                    {
                        context.report(
                            error: GraphQLError(
                                message: "Field \"\(parentType.name).\(fieldDef.name)\" argument \"\(argDef.name)\" is deprecated. \(deprecationReason)",
                                nodes: [node]
                            )
                        )
                    }
                }
            }
            if let node = node as? ObjectField {
                if
                    let inputObjectDef = context.parentInputType as? GraphQLInputObjectType,
                    let inputFieldDef = inputObjectDef.fields[node.name.value],
                    let deprecationReason = inputFieldDef.deprecationReason
                {
                    context.report(
                        error: GraphQLError(
                            message: "The input field \(inputObjectDef.name).\(inputFieldDef.name) is deprecated. \(deprecationReason)",
                            nodes: [node]
                        )
                    )
                }
            }
            if let node = node as? EnumValue {
                if
                    let enumValueDef = context.typeInfo.enumValue,
                    let deprecationReason = enumValueDef.deprecationReason,
                    let enumTypeDef = getNamedType(type: context.inputType)
                {
                    context.report(
                        error: GraphQLError(
                            message: "The enum value \"\(enumTypeDef.name).\(enumValueDef.name)\" is deprecated. \(deprecationReason)",
                            nodes: [node]
                        )
                    )
                }
            }
            return .continue
        }
    )
}
