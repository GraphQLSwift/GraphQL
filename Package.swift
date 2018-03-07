// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "GraphQL",
    
    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime.git", .branch("swift-4.1")),
    ],
    
    targets: [
        .target(name: "GraphQL", dependencies: ["Runtime"]),
        
        .testTarget(name: "GraphQLTests", dependencies: ["GraphQL"]),
    ]
)
