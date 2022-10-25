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
  ],
  dependencies: [
    .package(url: "https://github.com/JohnSundell/Files.git", from: "4.2.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.4"),
    .package(url: "https://github.com/apple/swift-syntax.git", exact: "0.50500.0"),
  ],
  targets: [
    .binaryTarget(
      name: "lib_InternalSwiftSyntaxParser",
      url: "https://github.com/keith/StaticInternalSwiftSyntaxParser/releases/download/5.5.2/lib_InternalSwiftSyntaxParser.xcframework.zip",
      checksum: "96bbc9ab4679953eac9ee46778b498cb559b8a7d9ecc658e54d6679acfbb34b8"
    ),
    .executableTarget(
      name: "PackageGeneratorCLI",
      dependencies: [
        "Files",
        "lib_InternalSwiftSyntaxParser",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "PackageGeneratorCLITests",
      dependencies: [
        "PackageGeneratorCLI"
      ]
    ),
  ]
)
