// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GraphQL",

    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],

    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime.git", from: "0.6.0"),

        // ⏱ Promises and reactive-streams in Swift built for high-performance and scalability.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0"),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime", "Async"]),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
