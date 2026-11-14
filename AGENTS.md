# Agent notes

PackageGeneratorCLI is a macOS command-line tool, not an app: it scans a Swift package's targets with swift-syntax
and writes the modules each one imports as JSON. Its only client is the
[PackageGenerator plugin](https://github.com/mackoj/PackageGeneratorPlugin), which downloads the release artifact
bundle and runs it. Usage is in `README.md`.

Read `CODING_STANDARDS.md` before writing code. Do not weaken it to make a change pass.

## How to work
- **Plan first.** For a change spanning several files or with more than one reasonable reading, state your
  assumptions and a short plan, then wait for approval.
- **Test first.** A bug gets a failing test that reproduces it; a feature gets a test that exercises it.
- **Smallest diff.** Every changed line traces to the request. Match the surrounding file's idioms.

## Build and test
- `swift build --build-tests` and `swift test`.
- Architecture rules: `swift test --package-path Architecture` runs the mechanical part of `CODING_STANDARDS.md` as
  [swift-llm-check](https://github.com/mackoj/swift-llm-check) rules, listed in `docs/architecture-rules.md`. A
  failure prints the rule, why it exists and how to fix it: fix the code, never add a baseline. A new or changed
  rule needs a `DetectorTests` case and `LLM_CHECK_RECORD=1 swift test --package-path Architecture` to regenerate
  the document.
- Benchmarks: `swift package --package-path Benchmarks benchmark`. Measuring, comparing and profiling:
  `docs/performance.md`.
- `site/index.html` is the landing page (GitHub Pages, `.github/workflows/pages.yml`). Its usage, JSON samples and
  version repeat the README: update them in the same change.

## Releasing
- Tags have no `v` prefix (`0.7.1`). Create the GitHub release, then run `./build.sh` (it clones `main`, builds
  release on Apple silicon and zips `package-generator-cli-arm64-apple-macosx.artifactbundle.zip`), upload the zip
  to the release, and update the URL and `swift package compute-checksum` value in the plugin's `Package.swift`.
