// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "GraphQL",
    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.10.1")),
        .package(url: "https://github.com/wickwirew/Runtime.git", .upToNextMinor(from: "2.1.0"))
    ],
    targets: [
        .target(
            name: "GraphQL", 
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Runtime", package: "Runtime")
            ]
        ),
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
