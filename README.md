# GraphQL

The Swift implementation for GraphQL, a query language for APIs created by Facebook.

[![Swift][swift-badge]][swift-url]
[![License][mit-badge]][mit-url]
[![Slack][slack-badge]][slack-url]
[![GitHub Actions][gh-actions-badge]][gh-actions-url]
[![Codebeat][codebeat-badge]][codebeat-url]

Looking for help? Find resources [from the community](http://graphql.org/community/).

## Graphiti

This repo only contains the core GraphQL implementation. For a better experience when creating your GraphQL schema use [Graphiti](https://github.com/GraphQLSwift/Graphiti).

## Contributing

Most of this repo mirrors the structure of the canonical GraphQL implementation written in Javascript/Typescript. If there is any feature missing, looking at the original code and "translating" it to Swift works, most of the time. For example:

### Swift

[/Sources/GraphQL/Language/AST.swift](https://github.com/GraphQLSwift/GraphQL/blob/master/Sources/GraphQL/Language/AST.swift)

### Javascript/Typescript

[/src/language/ast.js](https://github.com/graphql/graphql-js/blob/master/src/language/ast.js)


## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-5.2-orange.svg?style=flat
[swift-url]: https://swift.org

[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license

[slack-badge]: http://slack.zewo.io/badge.svg
[slack-url]: http://slack.zewo.io

[gh-actions-badge]: https://github.com/GraphQLSwift/GraphQL/workflows/Build/badge.svg
[gh-actions-url]: https://github.com/GraphQLSwift/GraphQl/actions?query=workflow%3ABuild

[codebeat-badge]: https://codebeat.co/badges/13293962-d1d8-4906-8e62-30a2cbb66b38
[codebeat-url]: https://codebeat.co/projects/github-com-graphqlswift-graphql
