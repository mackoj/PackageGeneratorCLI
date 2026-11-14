// swift-tools-version: 6.2
import PackageDescription

// PackageGeneratorCLI's benchmarks, on ordo-one/package-benchmark (https://www.swift.org/blog/benchmarks/). A separate
// package so the benchmark dependency never reaches the CLI. Run from the repository root:
// `swift package --package-path Benchmarks benchmark`.
let package = Package(
  name: "Benchmarks",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(name: "PackageGeneratorCLI", path: ".."),
    .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.38.0"),
  ],
  targets: [
    .executableTarget(
      name: "ScanBenchmarks",
      dependencies: [
        .product(name: "Benchmark", package: "package-benchmark"),
        .product(name: "PackageGeneratorCore", package: "PackageGeneratorCLI"),
        .product(name: "PackageGeneratorModels", package: "PackageGeneratorCLI"),
      ],
      path: "Benchmarks/ScanBenchmarks",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    ),
    // Reads two `benchmark --format markdown` outputs and prints each benchmark's p50 before and after.
    .executableTarget(name: "p50", path: "Tools/P50"),
    // Reads an exported Time Profiler table and prints the hottest functions (scripts/profile.sh).
    .executableTarget(name: "hotspots", path: "Tools/Hotspots"),
  ]
)
