// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "GraphQL",
    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/wickwirew/Runtime.git", .upToNextMinor(from: "2.1.0"))
    ],
    targets: [
        .target(name: "GraphQL", dependencies: ["NIO", "Runtime"]),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
