// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCodegen",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/yanagiba/swift-ast.git", from: "0.19.9"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "SwiftCodegen",
            dependencies: [
                .product(name: "SwiftAST+Tooling", package: "swift-ast")
            ]),
        .testTarget(
            name: "SwiftCodegenTests",
            dependencies: ["SwiftCodegen"]),
    ]
)
