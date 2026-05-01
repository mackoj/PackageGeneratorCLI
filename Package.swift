// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PackageGeneratorCLI",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .executable(name: "package-generator-cli", targets: ["PackageGeneratorCLI"]),
    .library(name: "PackageGeneratorModels", targets: ["PackageGeneratorModels"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.4"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"605.0.0"),
  ],
  targets: [
    .target(
      name: "PackageGeneratorModels"
    ),
    .executableTarget(
      name: "PackageGeneratorCLI",
      dependencies: [
        "PackageGeneratorModels",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "PackageGeneratorCLITests",
      dependencies: [
        "PackageGeneratorCLI",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6],
)
