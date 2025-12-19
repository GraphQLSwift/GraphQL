import Benchmark
import GraphQL

let benchmarks: @Sendable () -> Void = {
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
}
