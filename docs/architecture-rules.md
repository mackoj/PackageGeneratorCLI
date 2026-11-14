# Architecture rules

The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with [swift-llm-check](https://github.com/mackoj/swift-llm-check): `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.

## output

stdout, stderr and logging. Read before you print, log or report progress.

### The CLI never writes to stdout: no `print`, `debugPrint` or `dump`.

`stdout-is-not-written`: The PackageGenerator plugin runs the CLI as a subprocess and reads its result from the output file; humans read progress on stderr with `--verbose` (CODING_STANDARDS.md, "Output"). Text on stdout mixes with whatever the host prints and is lost in Xcode's plugin log. Diagnostics belong in os_log, where they can be filtered by subsystem and category.

**How to fix:** Log through a `Loggers` category (`Loggers.importParsing.warning(…)`), and for human progress call `verboseLog(…)` or `fputs(…, stderr)` behind `if verbose`.

Bad:

```swift
print("Parsed \(file.lastPathComponent)")
```

Good:

```swift
Loggers.importParsing.debug("Parsed \(file.lastPathComponent, privacy: .public)")
```

### An `os.Logger` is made only in `Sources/PackageGeneratorCore/Logging`.

`loggers-are-centralised`: Every log line uses the subsystem `com.mackoj.PackageGeneratorCLI` and one of the categories listed in `Loggers.swift`, so `log stream --predicate 'subsystem == "com.mackoj.PackageGeneratorCLI"'` and Console.app filters see everything (CODING_STANDARDS.md, "Output"). A `Logger` made elsewhere invents a subsystem or category nobody filters on.

**How to fix:** Use a `Loggers` category, or add one to `Loggers.swift` with a doc comment saying what it covers.

Bad:

```swift
let logger = Logger(subsystem: "PackageGenerator", category: "Parser")
```

Good:

```swift
Loggers.importParsing.debug("…")
```

## errors

How the CLI fails. Read before you add a code path that can fail.

### The CLI never traps: no `fatalError`, `preconditionFailure`, `try!` or force unwrap in `Sources`.

`failures-are-thrown`: A trap kills the plugin's subprocess with a signal and no message the user can act on. Failures are `CLIError` values with a readable `errorDescription` that ArgumentParser prints and turns into a non-zero exit (CODING_STANDARDS.md, "Errors"). A single unreadable file is logged and skipped, never fatal for the whole package.

**How to fix:** Throw a `CLIError` case (add one if none fits), or unwrap with `guard let … else { throw … }` or `?.`.

Bad:

```swift
let data = try! Data(contentsOf: inputFileURL)
resources != nil && resources!.isEmpty == false
```

Good:

```swift
do { data = try Data(contentsOf: inputFileURL) } catch {
    throw CLIError.ioError(path: inputFileURL.path, reason: error.localizedDescription)
}
resources?.isEmpty == false
```

## models

PackageGeneratorModels, the JSON contract with the plugin. Read before you touch a model.

### `PackageGeneratorModels` imports Foundation and nothing else.

`models-depend-on-foundation-only`: `PackageGeneratorModels` is a library product: it is the JSON contract between this CLI and the PackageGenerator plugin, and others may decode the output with it. Importing SwiftSyntax or ArgumentParser there would make every client build them (CODING_STANDARDS.md, "Models").

**How to fix:** Keep parsing and CLI code in `PackageGeneratorCLI`; models hold data and Codable logic only.

Bad:

```swift
// Sources/PackageGeneratorModels/ParsedPackage.swift
import SwiftSyntax
```

Good:

```swift
// Sources/PackageGeneratorModels/ParsedPackage.swift
import Foundation
```

### A public struct or enum in `PackageGeneratorModels` is declared `Codable` and `Sendable`.

`public-models-are-codable-and-sendable`: Models cross a process boundary as JSON and cross task boundaries inside the CLI, which processes targets concurrently under Swift 6 (CODING_STANDARDS.md, "Models"). A missing conformance is a source break to add later, since a client cannot add it.

**How to fix:** Declare both on the type itself, like its neighbours: `public struct ParsedPackage: Codable, Sendable`.

Bad:

```swift
public struct PathInfo: Codable {
```

Good:

```swift
public struct PathInfo: Codable, Sendable {
```

## concurrency

Sendable and shared state. Read before you add a class or share state across tasks.

### An `@unchecked Sendable` conformance has a comment that proves it safe.

`unchecked-sendable-explains-itself`: `@unchecked Sendable` turns off the compiler's data-race check for the type. The comment is the only proof left that the type is safe to share across the task groups that parse files concurrently (CODING_STANDARDS.md, "Concurrency").

**How to fix:** Prefer a value type or an `actor`. If neither fits, put a `//` comment just above the declaration that says what guards the mutable state. A `///` doc comment describes the type to its users and does not count.

Bad:

```swift
final class MockLogSink: LogSink, @unchecked Sendable {
```

Good:

```swift
// @unchecked Sendable: every access to `_entries` holds `lock`.
final class MockLogSink: LogSink, @unchecked Sendable {
```

## testing

Swift Testing, and no silenced tests. Read before you add, skip or mark a test.

### Tests use Swift Testing, never XCTest.

`tests-use-swift-testing`: The suite is Swift Testing only (CODING_STANDARDS.md, "Tests"): `@Test`, `#expect` and `#require` give one failure message style, parameterised tests and parallel runs.

**How to fix:** Write `@Test` functions with `#expect` and `#require`, and `import Testing`.

Bad:

```swift
import XCTest
final class GetImportVisitorTests: XCTestCase { func testPlain() { XCTAssertEqual(…) } }
```

Good:

```swift
import Testing
struct GetImportVisitorTests { @Test func parsesPlainImports() { #expect(…) } }
```

### No test or suite is `.disabled`, and `withKnownIssue` says why.

`tests-are-not-disabled`: A disabled test still reads as coverage while checking nothing, and a known issue without a reason hides a failing expectation nobody will come back to (CODING_STANDARDS.md, "Tests").

**How to fix:** Fix the code or the test. If the bug must wait, wrap the failing part in `withKnownIssue("<what and where it is tracked>")`.

Bad:

```swift
@Test(.disabled("flaky")) func parsesConditionalImports() {
withKnownIssue { … }
```

Good:

```swift
@Test func parsesConditionalImports() {
withKnownIssue("#if imports are not evaluated (mackoj/PackageGeneratorCLI#N)") { … }
```

## performance

The scan path. Read before you parse Swift or walk a syntax tree.

### Only `SwiftFileParser` calls `Parser.parse`, and nothing in `Sources` subclasses `SyntaxRewriter`.

`parsing-goes-through-the-import-region`: Parsing whole files was over 90% of a scan's time and allocations. `SwiftFileParser.imports(inSource:)` parses only the leading part of a file that can hold imports (`ImportRegion`), which made scans about 25 times faster (docs/performance.md, "What has paid off"). A second `Parser.parse` call site, or a `SyntaxRewriter` that walks and rebuilds every node, brings that cost back.

**How to fix:** Call `SwiftFileParser.imports(inSource:)` or `SwiftFileParser().parse(file:targetModuleName:)`. To read the tree, subclass `SyntaxVisitor` and return `.skipChildren` from nodes whose inside you do not need.

Bad:

```swift
let tree = Parser.parse(source: try String(contentsOf: file, encoding: .utf8))
final class ImportFinder: SyntaxRewriter { … }
```

Good:

```swift
let imports = SwiftFileParser.imports(inSource: source)
final class GetImportVisitor: SyntaxVisitor { … }
```
