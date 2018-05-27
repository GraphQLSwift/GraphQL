# GraphQL

The Swift implementation for GraphQL, a query language for APIs created by Facebook.

[![Swift][swift-badge]][swift-url]
[![License][mit-badge]][mit-url]
[![Slack][slack-badge]][slack-url]
[![Travis][travis-badge]][travis-url]
[![Codecov][codecov-badge]][codecov-url]
[![Codebeat][codebeat-badge]][codebeat-url]

Looking for help? Find resources [from the community](http://graphql.org/community/).

## Graphiti

This repo contains the core GraphQL implementation. For a better experience when creating your types use [Graphiti](https://github.com/GraphQLSwift/Graphiti).

**Graphiti** is a Swift library for building GraphQL schemas/types fast, safely and easily.


## Getting Started

An overview of GraphQL in general is available in the
[README](https://github.com/facebook/graphql/blob/master/README.md) for the
[Specification for GraphQL](https://github.com/facebook/graphql). That overview
describes a simple set of GraphQL examples that exist as [tests](Tests/GraphQLTests/StarWarsTests/)
in this repository. A good way to get started with this repository is to walk
through that README and the corresponding tests in parallel.

### Using GraphQL

Add GraphQL to your `Package.swift`

```swift
// swift-tools-version:4.0
import PackageDescription

let package = Package(
    dependencies: [
        .package(url: "https://github.com/GraphQLSwift/GraphQL.git", from: "0.0.0"),
    ]
)
```

GraphQL provides two important capabilities: building a type schema, and
serving queries against that type schema.

First, build a GraphQL type schema which maps to your code base.

```swift
import GraphQL

let schema = try GraphQLSchema(
    query: GraphQLObjectType(
        name: "RootQueryType",
        fields: [
            "hello": GraphQLField(
                type: GraphQLString,
                resolve: { _, _, _, _ in "world" }
            )
        ]
    )
)
```

This defines a simple schema with one type and one field, that resolves
to a fixed value. More complex examples are included in the [Tests](Tests/GraphQLTests/) directory.

Then, serve the result of a query against that type schema.

```swift
let query = "{ hello }"
let result = try graphql(schema: schema, request: query)
print(result)
```

Output:

```json
{
    "data": {
        "hello": "world"
    }
}
```

This runs a query fetching the one field defined. The `graphql` function will
first ensure the query is syntactically and semantically valid before executing
it, reporting errors otherwise.

```swift
let query = "{ boyhowdy }"
let result = try graphql(schema: schema, request: query)
print(result)
```

Output:

```json
{
    "errors": [
        {
            "locations": [
                {
                    "line": 1,
                    "column": 3
                }
            ],
            "message": "Cannot query field \"boyhowdy\" on type \"RootQueryType\"."
        }
    ]
}
```

### Field Execution Strategies

Depending on your needs you can alter the field execution strategies used for field value resolution.

By default the `SerialFieldExecutionStrategy` is used for all operation types (`query`, `mutation`, `subscription`).

To use a different strategy simply provide it to the `graphql` function:

```swift
try graphql(
    queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
    schema: schema,
    request: query
)
```

The following strategies are available:

* `SerialFieldExecutionStrategy`
* `ConcurrentDispatchFieldExecutionStrategy`

**Please note:** Not all strategies are applicable for all operation types.

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-4-orange.svg?style=flat
[swift-url]: https://swift.org
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[slack-image]: http://s13.postimg.org/ybwy92ktf/Slack.png
[slack-badge]: https://zewo-slackin.herokuapp.com/badge.svg
[slack-url]: http://slack.zewo.io
[travis-badge]: https://travis-ci.org/GraphQLSwift/GraphQL.svg?branch=master
[travis-url]: https://travis-ci.org/GraphQLSwift/GraphQL
[codecov-badge]: https://codecov.io/gh/GraphQLSwift/GraphQL/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/GraphQLSwift/GraphQL
[codebeat-badge]: https://codebeat.co/badges/13293962-d1d8-4906-8e62-30a2cbb66b38
[codebeat-url]: https://codebeat.co/projects/github-com-graphqlswift-graphql
