import PackageDescription

let package = Package(
    name: "GraphQL",
    dependencies: [
        .Package(url: "https://github.com/Zewo/CLibgraphqlparser.git", majorVersion: 0, minor: 1),
    ]
)
