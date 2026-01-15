// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "GraphQL",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.0.0")),
        .package(
            url: "https://github.com/apple/swift-distributed-tracing",
            .upToNextMajor(from: "1.0.0")
        ),
    ],
    targets: [
        .target(
            name: "GraphQL",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
            ]
        ),
        .testTarget(
            name: "GraphQLTests",
            dependencies: ["GraphQL"],
            resources: [
                .copy("LanguageTests/kitchen-sink.graphql"),
                .copy("LanguageTests/schema-kitchen-sink.graphql"),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5, .version("6")]
)
