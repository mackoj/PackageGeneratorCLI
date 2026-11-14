# PackageGenerator CLI

[![CI](https://github.com/mackoj/PackageGeneratorCLI/actions/workflows/ci.yml/badge.svg)](https://github.com/mackoj/PackageGeneratorCLI/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorCLI%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mackoj/PackageGeneratorCLI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorCLI%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mackoj/PackageGeneratorCLI)

**[Website](https://mackoj.github.io/PackageGeneratorCLI/)** ·
**[PackageGenerator plugin](https://mackoj.github.io/PackageGeneratorPlugin/)** ·
**[Performance](docs/performance.md)** ·
**[Architecture rules](docs/architecture-rules.md)**

The import scanner behind [PackageGenerator](https://github.com/mackoj/PackageGeneratorPlugin), the SwiftPM plugin
that writes your `Package.swift` from your code. Given a list of targets, it parses every Swift file with
[swift-syntax](https://github.com/swiftlang/swift-syntax), concurrently, and writes the modules each target imports
as JSON.

You normally don't install or run it yourself: the plugin downloads it as a prebuilt artifact bundle and runs it.

## What it reports

- Every import form counts by its top-level module: `@testable`, `@_exported`, `import struct Foundation.URL`, and
  imports inside `#if canImport(…)`.
- `public`, `internal` and `package` imports are dependencies; `private` and `fileprivate` imports are not.
- A target importing itself (or a test target importing `<Name>Tests`) is dropped. Files in DocC catalogs are skipped.
- Excludes are matched relative to the target, relative to the package (with or without `Sources/`/`Tests/`), or as
  absolute paths. The first `Resources` folder of a target is reported.
- Dependencies are sorted and deduplicated. stdout stays empty: `--verbose` prints progress to stderr, and
  diagnostics go to os_log under the subsystem `com.mackoj.PackageGeneratorCLI`.

## Usage

```
USAGE: package-generator-cli --output-file-url <output-file-url> --input-file-url <input-file-url> --package-directory <package-directory> [--verbose]

OPTIONS:
  --output-file-url <output-file-url>
  --input-file-url <input-file-url>
  --package-directory <package-directory>
  --verbose
  -h, --help              Show help information.
```

Input: a JSON array of targets, each with an optional test target and excludes. A bare path string, the original
format, still works.

```json
[
  {
    "target": { "path": "/App/Sources/Checkout", "name": "Checkout" },
    "test": { "path": "/App/Tests/CheckoutTests", "name": "CheckoutTests", "exclude": ["__Snapshots__"] }
  },
  "/App/Sources/Legacy"
]
```

Output: one entry per target and test target.

```json
[
  {
    "name": "Checkout",
    "isTest": false,
    "dependencies": ["Analytics", "Foundation", "Payments", "SwiftUI"],
    "path": "Sources/Checkout",
    "fullPath": "/App/Sources/Checkout",
    "resources": "Resources",
    "localDependencies": 0,
    "hasBiggestNumberOfDependencies": false
  }
]
```

Both types are in the `PackageGeneratorModels` library, if you want to build your own tooling on the output:

```swift
.package(url: "https://github.com/mackoj/PackageGeneratorCLI.git", from: "0.7.0"),
// …
.product(name: "PackageGeneratorModels", package: "PackageGeneratorCLI"),
```

## Building

Requires Swift 6.2 (Xcode 26) and macOS 13 or later.

```sh
swift build -c release
swift test
swift test --package-path Architecture                  # the rules in docs/architecture-rules.md
swift package --package-path Benchmarks benchmark       # see docs/performance.md
```

`PackageGeneratorCore` holds the scanner; it is a library product only so `Benchmarks/` can measure it and has no
API stability guarantee. Contributor notes are in [AGENTS.md](AGENTS.md) and [CODING_STANDARDS.md](CODING_STANDARDS.md).

## Release process

1. Create and publish a GitHub release, tagged without a `v` (`0.7.1`).
2. Run `./build.sh`. It clones `main`, builds in release mode and writes
   `package-generator-cli-arm64-apple-macosx.artifactbundle.zip` and its checksum.
3. Upload the zip to the release.
4. Update the `binaryTarget` URL and checksum in
   [PackageGeneratorPlugin's `Package.swift`](https://github.com/mackoj/PackageGeneratorPlugin/blob/main/Package.swift).
