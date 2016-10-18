# [![Logo](Images/logo.png)](/) GraphQL 

The Swift implementation for GraphQL, a query language for APIs created by Facebook.

[![Swift][swift-badge]][swift-url]
[![License][mit-badge]][mit-url]
[![Slack][slack-badge]][slack-url]
[![Travis][travis-badge]][travis-url]

Looking for help? Find resources [from the community](http://graphql.org/community/).


## Getting Started

An overview of GraphQL in general is available in the
[README](https://github.com/facebook/graphql/blob/master/README.md) for the
[Specification for GraphQL](https://github.com/facebook/graphql). That overview
describes a simple set of GraphQL examples that exist as [Tests](Tests/)
in this repository. A good way to get started with this repository is to walk
through that README and the corresponding tests in parallel.

### Using GraphQL

Add GraphQL to your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/GraphQLSwift/GraphQL.git", majorVersion: 0, minor: 1),
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
            "hello": GraphQLFieldConfig(
                type: GraphQLString,
                resolve: { _ in "world" }
            )
        ]
    )
)
```

This defines a simple schema with one type and one field, that resolves
to a fixed value. A more complex example is included in the top
level [Tests](Tests/) directory.

Then, serve the result of a query against that type schema.

```swift
let query = "{ hello }"

let result = try graphql(schema: schema, request: query)

// Prints
// data({"hello":"world"})
print(result)
```

This runs a query fetching the one field defined. The `graphql` function will
first ensure the query is syntactically and semantically valid before executing
it, reporting errors otherwise.

```swift
let query = "{ boyhowdy }"

let result = try graphql(schema: schema, request: query)

// Prints
// errors([Cannot query field "boyhowdy" on type "RootQueryType".])
print(result)
```

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[slack-image]: http://s13.postimg.org/ybwy92ktf/Slack.png
[slack-badge]: https://zewo-slackin.herokuapp.com/badge.svg
[slack-url]: http://slack.zewo.io
[travis-badge]: https://travis-ci.org/GraphQLSwift/GraphQL.svg?branch=master
[travis-url]: https://travis-ci.org/GraphQLSwift/GraphQL