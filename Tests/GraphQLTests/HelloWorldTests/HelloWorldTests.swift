@testable import GraphQL
import Testing

@Suite struct HelloWorldTests {
    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    resolve: { _, _, _, _ in
                        "world"
                    }
                ),
            ]
        )
    )

    @Test func hello() async throws {
        let query = "{ hello }"
        let expected = GraphQLResult(data: ["hello": "world"])

        let result = try await graphql(
            schema: schema,
            request: query
        )

        #expect(result == expected)
    }

    @Test func boyhowdy() async throws {
        let query = "{ boyhowdy }"

        let expected = GraphQLResult(
            errors: [
                GraphQLError(
                    message: "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
                    locations: [SourceLocation(line: 1, column: 3)]
                ),
            ]
        )

        let result = try await graphql(
            schema: schema,
            request: query
        )

        #expect(result == expected)
    }

    @Test func helloAsync() async throws {
        let query = "{ hello }"
        let expected = GraphQLResult(data: ["hello": "world"])

        let result = try await graphql(
            schema: schema,
            request: query
        )

        #expect(result == expected)
    }
}
