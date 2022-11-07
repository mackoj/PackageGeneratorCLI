# 📺 Package Generator CLI

Package Generator CLI is tool used by a [Package Generator](https://github.com/mackoj/PackageGeneratorPlugin) for extracting imports from code source. It use [swift-syntax](https://github.com/apple/swift-syntax.git) for the code analysing.

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

- Create a Github release 
- Publish Github release
- Run the `./build.sh` to create the artifactbundle 
- Upload the `artifactbundle` to the corresponding release page 
- Update [checksum](https://github.com/mackoj/PackageGeneratorPlugin/blob/2d2eb7e7c63a898bd71b14de8cd5acaab36eb7d2/Package.swift#L18) in https://github.com/mackoj/PackageGeneratorPlugin
