// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "GraphQL",
    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.10.1")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "0.0.3")),
    ],
    targets: [
        .target(
            name: "GraphQL", 
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
