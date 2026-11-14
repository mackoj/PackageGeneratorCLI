# Coding standards

PackageGeneratorCLI is the import scanner behind the [PackageGenerator](https://github.com/mackoj/PackageGeneratorPlugin)
plugin: it reads a JSON list of targets, parses every Swift file with swift-syntax and writes the modules each target
imports as JSON. These are the rules a change is reviewed against. The mechanical ones are enforced by
`swift test --package-path Architecture` and listed in [docs/architecture-rules.md](docs/architecture-rules.md).

## Output

- The result goes to `--output-file-url`, nothing else. stdout is never written (`print`, `debugPrint`, `dump`).
- Human progress goes to stderr, only with `--verbose` (`verboseLog`, or `fputs(…, stderr)` behind `if verbose`).
- Diagnostics go to os_log through a `Loggers` category (subsystem `com.mackoj.PackageGeneratorCLI`). A new
  category is added to `Loggers.swift` with a doc comment; no `Logger` is made anywhere else.
- Paths are logged `privacy: .private`; counts, module names and file names `privacy: .public`.

## Errors

- The CLI never traps: no `fatalError`, `preconditionFailure`, `try!` or force unwrap in `Sources`.
- Failures that stop the run are `CLIError` cases with a readable `errorDescription`.
- One unreadable or unparsable file is logged as a warning and skipped; a missing target directory is skipped.

## Models

- `PackageGeneratorModels` is the JSON contract with the plugin. It imports Foundation only, and its public types
  are `Codable` and `Sendable`.
- The JSON shape (keys, legacy string inputs, sorted `dependencies`) is public behaviour: change it only together
  with the plugin, and say so in the release notes.

## Concurrency

- Swift 6 language mode. Work that runs in task groups is a `Sendable` value type (`PackageProcessor`,
  `SwiftFileParser`); shared mutable state is an `actor`.
- `@unchecked Sendable` carries a `//` comment just above the declaration that says what guards the state (a `///` doc comment does not count).
- Output is deterministic whatever the scheduling: imports are deduplicated and sorted.

## Performance

- Swift is parsed only through `SwiftFileParser`, which parses the leading part of a file that can hold imports
  (`ImportRegion`). Trees are read with a `SyntaxVisitor` that skips what it does not need, never a `SyntaxRewriter`.
- The CLI scans whole packages: thousands of files. Time and memory both matter. A change to the scan path
  (discovery, parsing, import extraction, JSON) is measured with `Benchmarks/` and states its before and after in
  the pull request; see [docs/performance.md](docs/performance.md).

## Tests

- Swift Testing only: `@Test`, `#expect`, `#require`. No XCTest.
- No `.disabled` test. A known bug is wrapped in `withKnownIssue("<what, and where it is tracked>")`.
- A bug fix comes with a test that fails without it.
