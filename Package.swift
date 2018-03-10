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
        .package(url: "https://github.com/vapor/async.git", from: "1.0.0-rc"),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime", "Async"]),

        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
