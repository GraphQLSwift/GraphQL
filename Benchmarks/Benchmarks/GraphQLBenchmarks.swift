import Benchmark
import class Foundation.JSONEncoder
import GraphQL

let benchmarks: @Sendable () -> Void = {
    let encoder = JSONEncoder()

    Benchmark("graphql") { _ in
        let result = try await graphql(
            schema: starWarsSchema,
            request: """
                query NestedQuery {
                    hero {
                        name
                        friends {
                            name
                            appearsIn
                            friends {
                                name
                            }
                        }
                    }
                }
                """
        )
    }

    // Benchmarks the time to push a large static array through the GraphQL resolution system
    Benchmark("resolution") { _, schema in
        let result = try await graphql(
            schema: schema,
            request: """
                query {
                    collection {
                        value1
                        value2
                    }
                }
                """
        )
    } setup: {
        return collectionSchema(count: 10_000).schema
    }

    // Benchmarks the large static array exposed as a custom scalar
    // This avoids all the GraphQL resolution of each element item, and as such is way faster.
    Benchmark("resolution:scalar") { _, schema in
        let result = try await graphql(
            schema: schema,
            request: """
                query {
                    collection
                }
                """
        )
    } setup: {
        return collectionScalarSchema(count: 10_000)
    }

    // Benchmarks the time to encode a GraphQLResult
    Benchmark("encoding:GraphQLResult") { _, result in
        let result = try encoder.encode(result)
    } setup: {
        return try await graphql(
            schema: collectionSchema(count: 100_000).schema,
            request: """
                query {
                    collection {
                        value1
                        value2
                    }
                }
                """
        )
    }

    // Benchmarks the baseline time to encode a strongly typed Swift type (for comparison with encoding a GraphQLResult with `Map` types)
    Benchmark("encoding:baseline") { _, result in
        let result = try encoder.encode(result)
    } setup: {
        return BaselineResult(
            query: .init(
                collection: collectionSchema(count: 100_000).collection
            )
        )
    }
    struct BaselineResult: Codable {
        let query: Query

        struct Query: Codable {
            let collection: [CollectionItem]
        }
    }
}
