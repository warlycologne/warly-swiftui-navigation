// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "WarlyNavigation",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WarlyNavigation",
            targets: ["WarlyNavigation"]
        ),
        .library(
            name: "WarlyNavigationUI",
            targets: ["WarlyNavigationUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WarlyNavigation",
            dependencies: [
                "WarlyNavigationMacro",
            ]
        ),
        .testTarget(
            name: "WarlyNavigationTests",
            dependencies: ["WarlyNavigation"]
        ),
        .target(
            name: "WarlyNavigationUI",
            dependencies: ["WarlyNavigation"]
        ),
        .macro(
            name: "WarlyNavigationMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
//        .testTarget(
//            name: "WarlyNavigationMacroTests",
//            dependencies: [
//                "WarlyNavigationMacro",
//                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
//            ]
//        ),
    ]
)
