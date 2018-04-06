// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GraphQL",

    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],

    dependencies: [
        .package(url: "https://github.com/jseibert/Runtime.git", .branch("master")),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime"]),

        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
