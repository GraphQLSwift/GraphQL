// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GraphQL",

    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],

    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.7.2"),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime", "NIO"]),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
