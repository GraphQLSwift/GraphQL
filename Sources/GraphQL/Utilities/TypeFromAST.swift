public func typeFromAST(schema: GraphQLSchema, inputTypeAST: Type) -> (any GraphQLType)? {
    switch inputTypeAST {
    case let .listType(listType):
        if let innerType = typeFromAST(schema: schema, inputTypeAST: listType.type) {
            return GraphQLList(innerType)
        }
    case let .nonNullType(nonNullType):
        if let innerType = typeFromAST(schema: schema, inputTypeAST: nonNullType.type) {
            return GraphQLNonNull(innerType as! (any GraphQLNullableType))
        }
    case let .namedType(namedType):
        return schema.getType(name: namedType.name.value)
    }
    return nil
}
