// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PackageGeneratorCLI",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .executable(name: "package-generator-cli", targets: ["PackageGeneratorCLI"]),
    .library(name: "PackageGeneratorModels", targets: ["PackageGeneratorModels"])
  ],
  dependencies: [
    .package(url: "https://github.com/JohnSundell/Files.git", from: "4.2.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.4"),
    .package(url: "https://github.com/apple/swift-syntax", "509.0.0"..<"511.0.0"),
  ],
  targets: [
    .target(
      name: "PackageGeneratorModels"
    ),
    .executableTarget(
      name: "PackageGeneratorCLI",
      dependencies: [
        "Files",
        "PackageGeneratorModels",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
  ]
)
