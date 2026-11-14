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
    // The scanner behind the CLI, a library so `Benchmarks/` can measure it. Not a stable API.
    .library(name: "PackageGeneratorCore", targets: ["PackageGeneratorCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.4"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"605.0.0"),
  ],
  targets: [
    .target(
      name: "PackageGeneratorModels"
    ),
    .target(
      name: "PackageGeneratorCore",
      dependencies: [
        "PackageGeneratorModels",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),
    .executableTarget(
      name: "PackageGeneratorCLI",
      dependencies: [
        "PackageGeneratorCore",
        "PackageGeneratorModels",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "PackageGeneratorCLITests",
      dependencies: [
        "PackageGeneratorCore",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6],
)
