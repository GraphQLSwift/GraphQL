import GraphQL

// Contains a basic schema that holds a single, large static array. Used for testing processing throughput and
// large object encoding

struct CollectionItem: Codable, Sendable {
    let value1: String
    let value2: Int
}

let collectionItem = try! GraphQLObjectType(
    name: "CollectionItem",
    fields: [
        "value1": .init(
            type: GraphQLString,
            resolve: { source, _, _, _ in
                (source as! CollectionItem).value1
            }
        ),
        "value2": .init(
            type: GraphQLInt,
            resolve: { source, _, _, _ in
                (source as! CollectionItem).value2
            }
        )
    ]
)

func collectionSchema(count: Int) -> (schema: GraphQLSchema, collection: [CollectionItem]) {
    let staticCollection: [CollectionItem] = (0..<count).map {
        CollectionItem(value1: "\($0)", value2: $0)
    }
    let schema = try! GraphQLSchema(
        query: .init(
            name: "Query",
            fields: [
                "collection": .init(
                    type: GraphQLList(collectionItem),
                    resolve: {_, _, _, _ in
                        return staticCollection
                    }
                )
            ]
        ),
        types: [collectionItem]
    )
    return (schema, staticCollection)
}
