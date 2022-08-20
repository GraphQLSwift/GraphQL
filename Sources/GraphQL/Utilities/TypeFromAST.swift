func typeFromAST(schema: GraphQLSchema, inputTypeAST: Type) -> GraphQLType? {
    if let listType = inputTypeAST as? ListType {
        if let innerType = typeFromAST(schema: schema, inputTypeAST: listType.type) {
            return GraphQLList(innerType)
        }
    }

    if let nonNullType = inputTypeAST as? NonNullType {
        if let innerType = typeFromAST(schema: schema, inputTypeAST: nonNullType.type) {
            // Non-null types by definition must contain nullable types (since all types are nullable by default)
            return GraphQLNonNull(innerType as! GraphQLNullableType)
        }
    }

    guard let namedType = inputTypeAST as? NamedType else {
        return nil
    }

    return schema.getType(name: namedType.name.value)
}
