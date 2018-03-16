// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GraphQL",

    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],

    dependencies: [
        .package(url: "https://github.com/jseibert/Runtime.git", .branch("swift-4.1")),

        // ⏱ Promises and reactive-streams in Swift built for high-performance and scalability.
        .package(url: "https://github.com/vapor/core.git", .branch("nio")),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime", "Async"]),

        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
