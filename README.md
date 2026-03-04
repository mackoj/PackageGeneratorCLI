# Package Generator CLI

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorCLI%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mackoj/PackageGeneratorCLI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorCLI%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mackoj/PackageGeneratorCLI)

⚠️ This is in beta.

Package Generator CLI is a tool used by a [Package Generator](https://github.com/mackoj/PackageGeneratorPlugin) for extracting imports from code source. It uses [swift-syntax](https://github.com/apple/swift-syntax.git) for the code analyzing.

You should not install this or use this directly since it's part of [Package Generator](https://github.com/mackoj/PackageGeneratorPlugin) that you should use instead.

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

## Release process

- Create and publish a GitHub release for the desired tag; once it is published, the `Publish release artifact` workflow automatically runs `./build.sh` for that tag, builds the executable bundle, and uploads the `package-generator-cli-*-apple-macosx.artifactbundle.zip` asset to the release.
- The workflow also prints the `swift package compute-checksum` result for the generated bundle; copy that checksum into PackageGeneratorPlugin's `Package.swift` (see the existing [checksum reference](https://github.com/mackoj/PackageGeneratorPlugin/blob/2d2eb7e7c63a898bd71b14de8cd5acaab36eb7d2/Package.swift#L18)) so the plugin picks up the new artifact.
