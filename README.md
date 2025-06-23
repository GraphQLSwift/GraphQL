# GraphQL

[![Swift][swift-badge]][swift-url]
[![SSWG][sswg-badge]][sswg-url]
[![License][mit-badge]][mit-url]
[![Codebeat][codebeat-badge]][codebeat-url]


The Swift implementation for GraphQL, a query language for APIs created by Facebook.

Looking for help? Find resources [from the community](http://graphql.org/community/).

## Usage

### Schema Definition

The `GraphQLSchema` object can be used to define [GraphQL Schemas and Types](https://graphql.org/learn/schema/).
These schemas are made up of types, fields, arguments, and resolver functions. Below is an example:

```swift
let schema = try GraphQLSchema(
    query: GraphQLObjectType(                   // Defines the special "query" type
        name: "Query",
        fields: [
            "hello": GraphQLField(              // Users may query 'hello'
                type: GraphQLString,            // The result is a string type
                resolve: { _, _, _, _ in
                    "world"                     // The result of querying 'hello' is "world"
                }
            )
        ]
    )
)
```

For more complex schema examples see the test files.

This repo only contains the core GraphQL implementation and does not focus on the ease of schema creation. For a better experience
when creating your GraphQL schema use [Graphiti](https://github.com/GraphQLSwift/Graphiti).

### Execution

Once a schema has been defined queries may be executed against it using the global `graphql` function:

```swift
let result = try await graphql(
    schema: schema,
    request: "{ hello }"
)
```

The result of this query is a `GraphQLResult` that encodes to the following JSON:

```json
{ "hello": "world" }
```

### Subscription

This package supports GraphQL subscription, but until the integration of `AsyncSequence` in Swift 5.5 the standard Swift library did not
provide an event-stream construct. For historical reasons and backwards compatibility, this library implements subscriptions using an
`EventStream` protocol that nearly every asynchronous stream implementation can conform to.

To create a subscription field in a GraphQL schema, use the `subscribe` resolver that returns an `EventStream`. You must also provide a
`resolver`, which defines how to process each event as it occurs and must return the field result type. Here is an example:

```swift
let schema = try GraphQLSchema(
    subscribe: GraphQLObjectType(
        name: "Subscribe",
        fields: [
            "hello": GraphQLField(
                type: GraphQLString,
                resolve: { eventResult, _, _, _, _ in       // Defines how to transform each event when it occurs
                    return eventResult
                },
                subscribe: { _, _, _, _, _ in               // Defines how to construct the event stream
                    let asyncStream = AsyncThrowingStream<String, Error> { continuation in
                        let timer = Timer.scheduledTimer(
                            withTimeInterval: 3,
                            repeats: true,
                        ) {
                            continuation.yield("world")     // Emits "world" every 3 seconds
                        }
                    }
                    return ConcurrentEventStream<String>(asyncStream)
                }
            )
        ]
    )
)
```

To execute a subscription use the `graphqlSubscribe` function:

```swift
let subscriptionResult = try await graphqlSubscribe(
    schema: schema,
)
// Must downcast from EventStream to concrete type to use in 'for await' loop below
let concurrentStream = subscriptionResult.stream! as! ConcurrentEventStream
for try await result in concurrentStream.stream {
    print(result)
}
```

The code above will print the following JSON every 3 seconds:

```json
{ "hello": "world" }
```

The example above assumes that your environment has access to Swift Concurrency. If that is not the case, try using
[GraphQLRxSwift](https://github.com/GraphQLSwift/GraphQLRxSwift)

## Encoding Results

If you encode a `GraphQLResult` with an ordinary `JSONEncoder`, there are no guarantees that the field order will match the query,
violating the [GraphQL spec](https://spec.graphql.org/June2018/#sec-Serialized-Map-Ordering). To preserve this order, `GraphQLResult`
should be encoded using the `GraphQLJSONEncoder` provided by this package.

## Support

This package aims to support the previous three Swift versions.

For details on upgrading to new major versions, see [MIGRATION](MIGRATION.md).

## Contributing

If you think you have found a security vulnerability, please follow the
[Security guidelines](SECURITY.md).

Those contributing to this package are expected to follow the [Swift Code of Conduct](https://www.swift.org/code-of-conduct/), the
[Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/), and the
[SSWG Technical Best Practices](https://github.com/swift-server/sswg/blob/main/process/incubation.md#technical-best-practices).

This repo uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat), and includes lint checks to enforce these formatting standards.
To format your code, install `swiftformat` and run:

```bash
swiftformat .
```

Most of this repo mirrors the structure of
(the canonical GraphQL implementation written in Javascript/Typescript)[https://github.com/graphql/graphql-js]. If there is any feature
missing, looking at the original code and "translating" it to Swift works, most of the time. For example:

### Swift

[/Sources/GraphQL/Language/AST.swift](https://github.com/GraphQLSwift/GraphQL/blob/master/Sources/GraphQL/Language/AST.swift)

### Javascript/Typescript

[/src/language/ast.js](https://github.com/graphql/graphql-js/blob/master/src/language/ast.js)


## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-5.10-orange.svg?style=flat
[swift-url]: https://swift.org

[sswg-badge]: https://img.shields.io/badge/sswg-incubating-blue.svg?style=flat
[sswg-url]: https://swift.org/sswg/incubation-process.html#incubating-level

[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license

[gh-actions-badge]: https://github.com/GraphQLSwift/GraphQL/workflows/Build/badge.svg
[gh-actions-url]: https://github.com/GraphQLSwift/GraphQl/actions?query=workflow%3ABuild

[codebeat-badge]: https://codebeat.co/badges/13293962-d1d8-4906-8e62-30a2cbb66b38
[codebeat-url]: https://codebeat.co/projects/github-com-graphqlswift-graphql
