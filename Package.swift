// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "GraphQL",

    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],

    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime.git", .upToNextMinor(from: "2.1.0")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.14.1"),
    ],

    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime", "NIO"]),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
