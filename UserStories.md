# CLI v2 Architecture & UserStories

## Overview

PackageGeneratorCLI extracts Swift imports from source files and outputs JSON for consumption by the PackageGeneratorPlugin. Current implementation works but has scalability + maintainability gaps. This epic series modernizes the CLI following Swift 6 best practices, removes external dependencies, and adds performance optimizations.

---

# Epic 1: Dependency Refactoring & Error Handling

**Description:** Replace external `Files` library with native `FileManager`, add proper error handling with exit codes, structured error messages, and graceful degradation instead of `fatalError()` crashes. Establish a foundation for reliability + observability.

## User Story 1.1: Remove Files Library Dependency

**As a** maintainer,  
**I want** to remove the `Files` library and use native `FileManager`,  
**So that** the binary has fewer dependencies and is easier to distribute + maintain.

**Acceptance Criteria:**
- Remove `Files` from Package.swift `dependencies`
- Replace all `Files.Folder(path:)` with `FileManager.default.fileExists(atPath:)` + `FileManager.contentsOfDirectory(atPath:)`
- Replace all folder recursion with `FileManager.enumerator(atPath:)`
- All file operations use native `URL` + `FileManager` API
- Code compiles without warnings
- Binary size reduced (measure before/after)
- Unit tests pass without `Files` library
- No behavioral change from user perspective

## User Story 1.2: Define Structured CLIError Enum

**As a** error handler,  
**I want** a complete `CLIError` enum capturing all failure modes,  
**So that** callers can distinguish between different error types and respond appropriately.

**Acceptance Criteria:**
- Define `enum CLIError: LocalizedError`:
  - `fileNotFound(path: String)`
  - `directoryNotFound(path: String)`
  - `invalidJSON(file: String, reason: String)`
  - `parseFailure(file: String, reason: String)`
  - `ioError(path: String, reason: String)`
  - `invalidInput(reason: String)`
  - `writeFailure(path: String, reason: String)`
- Each case has descriptive `errorDescription` property
- Each case can be logged + displayed to user
- No information loss (all context preserved in error)

## User Story 1.3: Replace All fatalError() Calls

**As a** developer,  
**I want** to replace all `fatalError()` calls with proper error throws,  
**So that** the CLI never crashes and always exits gracefully.

**Acceptance Criteria:**
- Audit codebase: find all `fatalError()` calls (currently ~5-8 in cli.swift)
- Replace each with appropriate `throw CLIError.* case`
- Test each error path: verify exception thrown, not crash
- Document which function throws which error types
- No uncaught exceptions reach main (caught + logged)

## User Story 1.4: Exit Code Semantics

**As a** CI/CD pipeline,  
**I want** meaningful exit codes from CLI,  
**So that** I can detect failure type and respond appropriately.

**Acceptance Criteria:**
- Exit 0: success
- Exit 1: general error (file not found, parse failure)
- Exit 2: invalid input (bad arguments, schema validation)
- Exit 124: timeout (standard UNIX convention)
- Document exit codes in README
- Test each code path: verify correct exit code emitted
- Never exit without logging reason to stderr

## User Story 1.5: Error Messages to stderr

**As a** user,  
**I want** error messages written to stderr (not stdout),  
**So that** I can separate logs from actual JSON output.

**Acceptance Criteria:**
- All errors → `FileHandle.standardError.write()`
- All logs → `FileHandle.standardError.write()`
- JSON output → `FileHandle.standardOutput.write()` only
- User can redirect: `cli > output.json 2> errors.log`
- Plugin can capture stderr for diagnostics

## User Story 1.6: Configurable Log Levels

**As a** debugger,  
**I want** to control verbosity via `--log-level` flag,  
**So that** I can suppress noise in production and get traces locally.

**Acceptance Criteria:**
- Add `--log-level <level>` option with choices: `error`, `warning`, `info`, `debug`
- `--verbose` flag maps to `debug` (backward compat)
- Log format: `[LEVEL timestamp file:line] message`
- Only logs at or above threshold printed:
  - `error`: only errors
  - `warning`: errors + warnings
  - `info`: errors + warnings + info (default)
  - `debug`: all (including function entry/exit)
- Test: run with `error` level, verify no info logs

## User Story 1.7: Structured Logger Interface

**As a** maintainer,  
**I want** a `Logger` protocol separating logging logic from CLI,  
**So that** I can swap implementations (file, console, remote) easily.

**Acceptance Criteria:**
- Define `protocol Logger`: `error(_:)`, `warning(_:)`, `info(_:)`, `debug(_:)`
- Implement `ConsoleLogger` conforming to protocol
- Implement `FileLogger` (optional, for future use)
- CLI accepts `Logger` instance in initializer
- All logging calls go through logger (not print/fputs)
- Tests can inject mock logger + verify calls

## User Story 1.8: Error Recovery & Partial Results

**As a** plugin,  
**I want** CLI to continue parsing after individual file errors,  
**So that** I get partial results instead of total failure.

**Acceptance Criteria:**
- On file parse error: log warning, skip file, continue
- Collect errors in `ParseResult.warnings`
- Output includes: valid imports + list of failed files
- Plugin can choose to use partial results or fail
- Example: 50/51 files parsed, 1 error → return 50 results + 1 warning
- Test: corrupt one file in batch, verify others still processed

## User Story 1.9: Graceful Degradation on Permissions

**As a** user,  
**I want** CLI to skip unreadable files gracefully,  
**So that** parse continues for accessible files.

**Acceptance Criteria:**
- Check file readability before parsing
- If not readable: log warning, skip, continue
- Collect unreadable files in warnings
- Output includes: files skipped due to permissions
- Test: remove read permission on one file, verify others processed


---

# Epic 2: Performance Optimization (Parallelization & Caching)

**Description:** Speed up CLI by parsing files in parallel (multi-core utilization) and optionally caching parse results to avoid re-work. Target 3-4x speedup on large projects + optional persistent caching.

## User Story 2.1: File Discovery & Listing

**As a** optimizer,  
**I want** to efficiently discover all `.swift` files before parsing,  
**So that** I can then parallelize parsing without I/O overhead.

**Acceptance Criteria:**
- Implement `func discoverSwiftFiles(in:excludingPatterns:)` → `[URL]`
- Recursively find all `.swift` files in target directories
- Skip `.build/`, `.swiftpm/`, `DerivedData/` by default
- Respect user-provided exclude patterns (Epic 5.3)
- Return sorted URLs (deterministic order)
- Log discovery stats: `[INFO] Found 150 .swift files in 2.3s`
- Test: 1000 file project discovers correctly
- No actual parsing yet (prepare for Epic 2.2)

## User Story 2.2: TaskGroup-based Concurrent Parsing

**As a** user,  
**I want** files parsed in parallel on multiple cores,  
**So that** extraction completes 3-4x faster than sequential parsing.

**Acceptance Criteria:**
- Implement `func parseFilesInParallel(_:maxConcurrent:)` → `async [ParseResult]`
- Use `withTaskGroup(of:returning:)` to spawn parse tasks
- Each task: parse one file independently via `GetImportVisitor`
- Collect results preserving input order (via index tracking)
- Add `--max-concurrent-tasks <n>` flag (default: `ProcessInfo.processInfo.activeProcessorCount`)
- Limit concurrency to prevent resource exhaustion
- Benchmark: 100+ file project shows 3-4x speedup vs sequential
- Test: verify result count = input count (no loss)
- Test: different max-concurrent settings work correctly

## User Story 2.3: Concurrent Task Cancellation

**As a** user,  
**I want** running tasks to be cancelled cleanly,  
**So that** timeouts or interrupts don't leak resources.

**Acceptance Criteria:**
- TaskGroup automatically cancels remaining tasks on first error
- Implement graceful cleanup on cancellation
- Any in-flight parsing stops + resources released
- Test: cancel mid-parse, verify no zombie tasks
- Test: SIGINT (Ctrl+C) cancels + exits cleanly

## User Story 2.4: In-Memory Parse Cache

**As a** developer,  
**I want** parsed results cached during a single CLI run,  
**So that** if same file is requested twice, second lookup is instant.

**Acceptance Criteria:**
- Implement `ParseCache` class: `[String: [String]]` (file path → imports)
- Check cache before parsing: hit → return cached imports, miss → parse + cache
- In-memory only (ephemeral, per-run)
- Always active (no flag needed)
- Thread-safe: use actor or concurrent dictionary
- Log cache hit/miss stats: `[INFO] Cache hits: 5/150 (3%)`
- Test: parse same file twice, second is instant

## User Story 2.5: Persistent Disk Cache

**As a** developer iterating locally,  
**I want** optional persistent cache across CLI invocations,  
**So that** re-runs on unchanged files skip parsing entirely.

**Acceptance Criteria:**
- Add `--use-cache` flag to enable disk caching
- Cache location: `<package>/.build/.package-generator-cache/` (adjacent to build artifacts)
- Cache key: `sha256(file_path + file_mtime)` (mtime = file modification time)
- Cache value: JSON file containing parsed imports
- On run: check cache key, if hit use cached, if miss parse + save
- Add `--clear-cache` flag to invalidate all entries
- Log cache stats: `[INFO] Disk cache: 45/100 hits (45%)`
- Test: parse, verify cache created; parse again, verify cache hit
- Test: modify file, verify cache invalidated + re-parsed
- Test: `--clear-cache` deletes cache directory

## User Story 2.6: Cache Invalidation Strategy

**As a** developer,  
**I want** caches to invalidate automatically when files change,  
**So that** I never parse stale code.

**Acceptance Criteria:**
- Disk cache key includes: file path + file mtime (modification time)
- If file mtime newer than cache entry mtime: cache stale → re-parse
- If file deleted: remove cache entry
- Test: change file, verify cache invalidated
- Test: delete file, verify cache entry cleaned up
- Test: move file to new path, verify treated as new file

## User Story 2.7: Batch Input Mode

**As a** CI/CD pipeline,  
**I want** to parse multiple targets in single CLI call,  
**So that** we don't spawn CLI 50 times.

**Acceptance Criteria:**
- Rename `--input-file-url` to accept multiple:
  - Option 1: `--input-file-url <url1> --input-file-url <url2>` (repeatable)
  - Option 2: `--input-list <json-file>` with array of inputs
- Process all inputs in single parallelized batch
- Output single JSON array with all results
- Parallelization applies across entire batch (not per-input)
- Caching applies across batch items
- Test: batch 50 targets, verify processed in < time of 3 sequential

## User Story 2.8: Progress Reporting

**As a** user running long-running batch,  
**I want** progress updates during parsing,  
**So that** I know CLI is alive and not hung.

**Acceptance Criteria:**
- Every N files parsed: emit `[INFO] Progress: X/Y files parsed (Z%)`
- Interval: N = 10% of total files (e.g., 100 files → every 10 parsed)
- Only on `--verbose` or `--log-level debug`
- Format: `[INFO] Progress: 45/150 files parsed (30%)`
- Test: 1000 file parse shows progress updates

## User Story 2.9: Performance Metrics Collection

**As a** developer,  
**I want** detailed performance metrics after each run,  
**So that** I can measure improvements + identify bottlenecks.

**Acceptance Criteria:**
- Collect metrics:
  - Total elapsed time
  - Files discovered count
  - Files parsed count
  - Parse errors count
  - Cache hits/misses count
  - Parallel task count used
- Output metrics in JSON diagnostic block (Epic 6.1)
- Log on info level: `[INFO] Completed in 2.34s: 150 files, 145 parsed, 5 errors, 0 cache hits`
- Test: verify metrics accurate + realistic


---

# Epic 3: Decouple from Plugin Models & Generic I/O

**Description:** Make CLI independent of plugin-specific data structures. Accept + output generic JSON schemas that don't change when plugin evolves. Provide adapter layer for plugin consumption.

## User Story 3.1: Define Generic Input Schema

**As a** CLI maintainer,  
**I want** to define a minimal generic input schema independent of plugin,  
**So that** other tools can use CLI without coupling to PackageGeneratorPlugin.

**Acceptance Criteria:**
- Define minimal input schema:
  ```json
  {
    "version": "1.0",
    "targets": [
      {
        "path": "/absolute/path/to/target",
        "name": "TargetName",
        "exclude_patterns": ["__Snapshots__", "*.tmp.swift"]
      }
    ]
  }
  ```
- Path must be absolute
- name: unique identifier for target
- exclude_patterns: optional array of glob patterns
- Document in README: this is "GenericInput" schema
- Make it generic enough for any Swift parser tool

## User Story 3.2: Define Generic Output Schema

**As a** CLI consumer,  
**I want** generic output not tied to plugin models,  
**So that** other tools can consume CLI output directly.

**Acceptance Criteria:**
- Define minimal output schema per target:
  ```json
  {
    "target": "TargetName",
    "imports": ["Foundation", "UIKit", "MyLocalLib"],
    "reexported_imports": ["SharedDeps"],
    "warnings": [
      "File unreadable: /path/to/file",
      "Parse error: /path/to/other/file - syntax error"
    ]
  }
  ```
- imports: array of top-level module names
- reexported_imports: modules marked @_exported
- warnings: array of non-fatal issues
- All paths absolute + human-readable
- Output is array of targets

## User Story 3.3: Implement Input Adapter

**As a** plugin,  
**I want** to transform my PackageInformation → generic schema,  
**So that** I can pass to CLI without coupling.

**Acceptance Criteria:**
- Implement `PluginAdapter.toGenericInput(_:) → GenericInput`
- Takes array of `PackageInformation`
- Converts to generic input schema
- Adapter lives in CLI as public library
- Tests verify round-trip conversion preserves data

## User Story 3.4: Implement Output Adapter

**As a** plugin,  
**I want** to transform generic CLI output → my ParsedPackage,  
**So that** I can process results without tight coupling.

**Acceptance Criteria:**
- Implement `PluginAdapter.toPluginOutput(_:) → [ParsedPackage]`
- Takes generic output from CLI
- Converts to plugin's `ParsedPackage` format
- Adapter handles version compatibility
- Tests verify output matches expected format

## User Story 3.5: CLI Core Works Without Plugin

**As a** standalone tool user,  
**I want** to use CLI independently of PackageGeneratorPlugin,  
**So that** other projects can benefit from import extraction.

**Acceptance Criteria:**
- CLI takes generic input (not PackageInformation)
- CLI outputs generic output
- No imports of plugin types in CLI core
- Plugin types only in adapter layer
- CLI compiles + runs without plugin package installed
- Test: run CLI standalone with only generic I/O

## User Story 3.6: Version Compatibility Handling

**As a** maintainer,  
**I want** adapter to handle schema version mismatches,  
**So that** old plugins work with new CLI (backward compat).

**Acceptance Criteria:**
- Generic schemas include `version: "1.0"`
- Adapter checks version on input
- If mismatch: log warning, attempt compatibility mode
- Define migration path for version 1.0 → 2.0
- Test: old plugin input → runs with graceful fallback

## User Story 3.7: Standalone Import Extraction Library

**As a** developer,  
**I want** to use import extraction as a library (not just CLI),  
**So that** I can embed in other tools.

**Acceptance Criteria:**
- Extract core logic into `PackageGeneratorCLILib` target
- Export `public func extractImports(from:excluding:) async throws -> [String]`
- CLI is thin wrapper around library
- Library has zero external dependencies (except SwiftSyntax)
- Tests for library can be run without CLI
- Documentation: "Embedding Import Extraction" guide


---

# Epic 4: Swift 6 Concurrency & Modern Patterns

**Description:** Adopt Swift 6.2 best practices: structured concurrency with `withThrowingTaskGroup`, actor isolation for shared state, `@concurrent` for CPU-bound parsing, Sendable conformance, and cooperative cancellation. All stories reviewed against `swift-concurrency-pro` references (actors.md, structured.md, bug-patterns.md, cancellation.md, new-features.md).

> **Reviewer note (swift-concurrency-pro):** The original Epic 4 had three correctness bugs:
> 1. Actor methods were marked `mutating` — actors are reference types, `mutating` is illegal and meaningless on actor funcs.
> 2. `.unsafeFlags` used for strict concurrency — replaced by `.swiftLanguageMode(.v6)` in modern Package.swift.
> 3. Task group code called `collector.addImports(result)` without `await` — actor crossing requires `await`.
> These are corrected below.

## User Story 4.1: Actor-based Import Collector

**As a** concurrent system designer,  
**I want** import collection protected by actor isolation,  
**So that** concurrent parsing tasks safely append results without manual locks.

**Acceptance Criteria:**
- Implement `actor ImportCollector` (reference type — **no** `mutating` on methods):
  ```swift
  actor ImportCollector {
    private var results: [String: [String]] = [:]

    // NOT mutating — actors are reference types
    func addImports(_ imports: [String], forTarget target: String) {
      results[target, default: []].append(contentsOf: imports)
    }

    func getImports(forTarget target: String) -> [String] {
      results[target] ?? []
    }

    func allResults() -> [String: [String]] { results }
  }
  ```
- Callers always `await collector.addImports(...)` — actor crossing requires `await`
- No `NSLock`, `DispatchSemaphore`, or `DispatchQueue` in import accumulation
- Compiler enforces thread-safety (Swift 6 strict concurrency, zero warnings)
- Tests: concurrent adds from 50 tasks → results contain all expected imports, no duplicates lost

## User Story 4.2: Sendable Conformance for Crossing Types

**As a** Swift 6 compliance officer,  
**I want** all types crossing concurrency boundaries to be `Sendable`,  
**So that** the compiler can prove data-race freedom.

**Acceptance Criteria:**
- Make `Sendable` (prefer `struct` over `class`):
  - `ParseResult` — value type carrying file path + extracted imports
  - `GenericInput`, `GenericOutput` — I/O schemas
  - `CLIError` — error enum
  - Any nested types (arrays, enums)
- Do **not** use `@unchecked Sendable` to silence compiler errors — fix the underlying type instead (use value types or actors)
- If a type genuinely needs `@unchecked Sendable` (e.g. a lock-protected class), add a comment: `// @unchecked Sendable: protected by NSLock on lines X–Y`
- Tests verify Sendable compliance under strict concurrency

## User Story 4.3: Enable Swift 6 Language Mode

**As a** maintainer,  
**I want** the package to compile under Swift 6 language mode with zero warnings,  
**So that** data-race safety is guaranteed by the compiler.

**Acceptance Criteria:**
- Use modern Package.swift syntax (not deprecated `.unsafeFlags`):
  ```swift
  .executableTarget(
    name: "PackageGeneratorCLI",
    // ...
    swiftSettings: [
      .swiftLanguageMode(.v6)
    ]
  )
  ```
- `swift build` produces zero concurrency warnings/errors
- CI fails the build on any strict-concurrency regression
- Document in README: "This package targets Swift 6 language mode"

## User Story 4.4: @concurrent for CPU-Bound Parsing (Swift 6.2)

**As a** performance engineer,  
**I want** import parsing functions annotated `@concurrent`,  
**So that** they run on the cooperative thread pool instead of blocking the caller's executor.

**Background:** In Swift 6.2, a plain `nonisolated async` function now _stays on the caller's executor_ by default (behavior change from Swift 6.0). File parsing is CPU-bound; it must explicitly opt into background execution with `@concurrent` to avoid blocking the main actor.

**Acceptance Criteria:**
- Mark the parsing entry point with `@concurrent`:
  ```swift
  nonisolated struct SwiftFileParser {
    @concurrent
    func parse(file: URL, targetModuleName: String) async throws -> ParseResult {
      // CPU-bound: tokenize + walk AST — safe to run on cooperative pool
      let source = try String(contentsOf: file, encoding: .utf8)
      let sourceFile = Parser.parse(source: source)
      let visitor = GetImportVisitor(viewMode: .all)
      _ = visitor.visit(sourceFile)
      return ParseResult(file: file, imports: visitor.drain(), targetModuleName: targetModuleName)
    }
  }
  ```
- Do **not** use `Task.detached` to force background execution — `@concurrent` is the correct Swift 6.2 tool
- Verify: calling `parse(file:)` from `@MainActor` context does not block the main actor
- Tests confirm parsing work runs off the main executor

## User Story 4.5: Structured Concurrency with Bounded TaskGroup

**As a** performance optimizer,  
**I want** file parsing using `withThrowingTaskGroup` with a concurrency cap,  
**So that** task lifecycle is clear, cancellation propagates, and memory is bounded on large projects.

**Acceptance Criteria:**
- Use `withThrowingTaskGroup` (not unstructured `Task {}`):
  ```swift
  let allResults = try await withThrowingTaskGroup(
    of: (URL, Result<ParseResult, Error>).self
  ) { group in
    let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount * 2
    var iterator = files.makeIterator()

    // Seed initial batch
    for _ in 0..<maxConcurrent {
      guard let file = iterator.next() else { break }
      group.addTask(name: "parse:\(file.lastPathComponent)") {
        do {
          return (file, .success(try await parser.parse(file: file, targetModuleName: targetName)))
        } catch {
          return (file, .failure(error))
        }
      }
    }

    var collected: [ParseResult] = []

    // Sliding window: as each finishes, start the next
    for try await (file, result) in group {
      switch result {
      case .success(let r):
        collected.append(r)
      case .failure(let error):
        logger.warning("Parse failed for \(file.lastPathComponent): \(error)")
      }
      if let next = iterator.next() {
        group.addTask(name: "parse:\(next.lastPathComponent)") {
          do {
            return (next, .success(try await parser.parse(file: next, targetModuleName: targetName)))
          } catch {
            return (next, .failure(error))
          }
        }
      }
    }
    return collected
  }
  ```
- Concurrency cap defaults to `ProcessInfo.activeProcessorCount * 2`; overridable via `--max-concurrent-tasks`
- Partial results preserved: one parse failure does **not** cancel the whole group (wrap in `Result` inside each child)
- Parent cancellation cancels all children (structured — free)
- Task names (Swift 6.2) used for debugging: `"parse:<filename>"`
- Tests: 200 files, verify all parsed; cancel mid-run, verify no zombie tasks; one failing file, verify 199 succeed

## User Story 4.6: Cooperative Cancellation with CancellationError Isolation

**As a** system designer,  
**I want** CPU-bound loops to check for cancellation and catch blocks to treat `CancellationError` as normal lifecycle,  
**So that** long parses respond promptly to cancellation without showing spurious errors.

**Acceptance Criteria:**
- Insert `try Task.checkCancellation()` at the start of each file parse and inside any inner loops (CPU-bound loops have no `await` → no implicit cancellation check):
  ```swift
  func parse(file: URL, targetModuleName: String) async throws -> ParseResult {
    try Task.checkCancellation()
    // ... parse ...
  }
  ```
- Catch blocks **isolate** `CancellationError` before handling other errors:
  ```swift
  do {
    try await runParsing()
  } catch is CancellationError {
    // Normal lifecycle — caller cancelled. Log at debug, do not show error.
    logger.debug("Parsing cancelled by caller")
  } catch {
    logger.error("Parsing failed: \(error)")
    throw error
  }
  ```
- Exit code 124 when CLI is cancelled via timeout (UNIX convention)
- Tests: trigger cancellation, verify no error alert shown, verify `CancellationError` not re-thrown

## User Story 4.7: Replace Manual Synchronization with Actors

**As a** concurrency engineer,  
**I want** to replace any manual `NSLock`/`DispatchQueue` with actors,  
**So that** synchronization is expressed in the type system and verified by the compiler.

**Acceptance Criteria:**
- Grep for `NSLock`, `DispatchSemaphore`, `DispatchQueue`, `objc_sync_enter`: replace with actor isolation
- Thread Sanitizer (`swift test --sanitize=thread`) passes with zero races
- Performance benchmark: actor version equal or faster than mutex on 4+ cores

## User Story 4.8: Zero nonisolated(unsafe) Policy

**As a** maintainer,  
**I want** a project policy of zero `nonisolated(unsafe)` usages,  
**So that** the compiler's data-race guarantee is never manually bypassed.

**Acceptance Criteria:**
- Target: zero `nonisolated(unsafe)` in codebase
- If unavoidable (e.g. bridging a third-party C library), require:
  - Code comment explaining the invariant that makes it safe
  - PR must get explicit approval from a second reviewer
- `grep -r "nonisolated(unsafe)" Sources/` in CI, fails if count > 0 (unless whitelisted via `// nonisolated(unsafe): approved`)

---

# Epic 5: Enhanced Import Detection & Testing

**Description:** Improve import extraction to handle edge cases, add comprehensive unit tests, support re-exports.

## User Story 5.1: Re-exported Import Detection

**As a** a user of modular code,  
**I want** the CLI to detect `@_exported import` statements,  
**So that** transitive dependencies are correctly captured.

**Acceptance Criteria:**
- Update `GetImportVisitor` to detect `@_exported import Foo` syntax
- Mark re-exported imports with metadata: `{"import": "Foo", "reexported": true}`
- Plugin can then understand transitive dep chains
- Test case: file with `@_exported import A` and `import B` returns both

## User Story 5.2: Unit Tests for Import Visitor

**As a** developer,  
**I want** comprehensive unit tests for `GetImportVisitor`,  
**So that** edge cases are caught before reaching plugin.

**Acceptance Criteria:**
- Test file snippets:
  - `import Foundation` → captures "Foundation"
  - `import A.B.C` → captures "A" (top-level)
  - `import UIKit` → skips if private import
  - `@_exported import Foo` → captures "Foo" with reexported=true
  - Comments + string literals with "import" → ignored
  - Conditional compilation `#if os(iOS)` → handled
- Coverage > 90% on `GetImportVisitor`
- All edge cases documented in test names

## User Story 5.3: File Pattern Exclusion

**As a** user,  
**I want** to exclude files by glob pattern,  
**So that** I can skip test fixtures, generated code, etc.

**Acceptance Criteria:**
- Add `--exclude-patterns <pattern>` (repeatable flag)
- Patterns: `**/__Snapshots__/**`, `**/Generated/**`, `*.tmp.swift`
- Applied during file discovery (fast)
- Log excluded file count: `[INFO] Excluded 12 files via patterns`
- Default excludes (always): `.build/`, `.swiftpm/`, `DerivedData/`

---

# Epic 6: Observability & Diagnostics

**Description:** Add rich diagnostics output, metrics collection, structured logging for debugging.

## User Story 6.1: JSON Diagnostic Output

**As a** the plugin,  
**I want** detailed diagnostic info beyond just imports,  
**So that** I can report issues to user clearly.

**Acceptance Criteria:**
- Extend output schema to include:
  ```json
  {
    "target": "TargetName",
    "imports": [...],
    "warnings": ["File unreadable: xyz"],
    "metrics": {
      "files_scanned": 15,
      "files_parsed": 14,
      "parse_errors": 1,
      "elapsed_ms": 245
    }
  }
  ```
- Plugin can extract + display warnings to user
- Metrics useful for debugging performance

## User Story 6.2: Structured Logging for Debugging

**As a** debugger,  
**I want** JSON-formatted logs (not printf),  
**So that** I can parse + analyze import extraction in detail.

**Acceptance Criteria:**
- Add `--log-format <text|json>` flag
- JSON format:
  ```json
  {
    "timestamp": "2026-05-01T12:00:00Z",
    "level": "info",
    "message": "Parsed file",
    "target": "Core",
    "file": "Sources/Core/Models.swift",
    "imports_found": 3
  }
  ```
- Can pipe to external tools (jq, ELK stack, etc.)
- Text format for human readability (default)

---

# Epic 7: Deployment & Distribution

**Description:** Improve build + distribution process, add version management, support multiple platforms.

## User Story 7.1: Multi-Platform Binary Builds

**As a** user of Apple Silicon,  
**I want** CLI binaries for both x86_64 + ARM64,  
**So that** I don't need Rosetta.

**Acceptance Criteria:**
- Update `build.sh` to cross-compile:
  - `package-generator-cli-arm64-apple-macosx`
  - `package-generator-cli-x86_64-apple-macosx`
- Both included in `.artifactbundle`
- Plugin auto-selects correct binary at runtime
- Each binary signed + notarized

## User Story 7.2: Version Management

**As a** maintainer,  
**I want** CLI version baked into binary,  
**So that** plugin can verify compatibility.

**Acceptance Criteria:**
- Add `--version` flag to CLI
- Outputs: `package-generator-cli version 1.0.0 (swift 6.2)`
- Hardcoded in Package.swift (single source of truth)
- Plugin checks version on startup, warns if mismatch

## User Story 7.3: Release Automation

**As a** maintainer,  
**I want** to automate releases via GitHub Actions,  
**So that** I don't manually build + upload binaries.

**Acceptance Criteria:**
- GitHub Actions workflow on tag: `v*`
- Builds both architectures
- Creates `.artifactbundle`
- Uploads to GitHub release
- Outputs checksum for plugin Package.swift
- Workflow produces pinnable GitHub action for other projects

---

# Implementation Roadmap

## Phase 1: Stability (High Impact, Low Risk)
- Epic 1: Dependencies + error handling
- Epic 5.2: Unit tests for GetImportVisitor
- Estimated: 2-3 weeks

## Phase 2: Performance (Medium Impact, Medium Risk)
- Epic 2: Parallelization + caching
- Epic 6: Observability
- Estimated: 3-4 weeks

## Phase 3: Modern Patterns (Low Impact, Medium Risk)
- Epic 4: Swift 6 concurrency
- Epic 5.1: Re-exported imports
- Estimated: 2-3 weeks

## Phase 4: Decoupling & Distribution (Low Impact, Low Risk)
- Epic 3: Generic I/O schemas
- Epic 7: Multi-platform + automation
- Estimated: 2 weeks

---

# Success Metrics

✅ **Phase 1:**
- Zero `fatalError()` calls in codebase
- Unit test coverage > 85% for import extraction
- No external file library dependency

✅ **Phase 2:**
- 3-4x faster parse on 100+ file project (vs current)
- Cache hit rate > 40% on local iterations
- Disk cache reduces re-runs by 50%

✅ **Phase 3:**
- Swift 6 strict concurrency: zero warnings
- All types `Sendable`
- Re-exported imports detected + tested

✅ **Phase 4:**
- CLI usable standalone (not coupled to plugin)
- Binaries for both x86_64 + ARM64
- Release automation 100% hands-off (GitHub Actions)

---

# Open Questions

1. **Caching strategy:** In-memory only (fast, ephemeral) or disk cache (persistent but slower)?
   - **Proposal:** Both. In-memory always, disk cache opt-in via `--use-cache`.

2. **Timeout handling:** If CLI hits timeout, should it output partial results or fail?
   - **Proposal:** Output partial results + warning, exit 124.

3. **Swift version:** Require Swift 6.0+ or stay on 5.9?
   - **Proposal:** Require Swift 6.0 for new features (Epic 4), maintain 5.9 compat in Epic 1-2.

4. **Re-exported imports:** Should plugin follow re-export chains transitively?
   - **Proposal:** CLI detects + marks them, plugin decides whether to follow.

---

# References

- Current CLI: `/Users/mac-JMACKO01/Developer/PackageGeneratorCLI`
- V2 Plugin: `/Users/mac-JMACKO01/Developer/PackageGeneratorPlugin` (consumer)
- Swift Concurrency: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- ArgumentParser: https://github.com/apple/swift-argument-parser

---

# Epic 5: Enhanced Import Detection & Testing

**Description:** Improve import extraction to handle edge cases, add comprehensive unit tests for 85%+ coverage, support re-exports, and implement file filtering.

## User Story 5.1: Re-exported Import Detection

**As a** modular code user,  
**I want** the CLI to detect `@_exported import` statements,  
**So that** transitive dependencies are correctly captured and marked.

**Acceptance Criteria:**
- Update `GetImportVisitor` to detect `@_exported import Foo` syntax
- Extract modifier information from `ImportDeclSyntax`
- Mark re-exported imports in output: `"reexported_imports": ["Foo", "Bar"]`
- Distinguish from regular imports: `"imports": ["Foundation"]`
- Test: file with `@_exported import A` and `import B` returns both lists
- Test: only re-exported flagged separately

## User Story 5.2: Private/Package Modifier Support

**As a** strict encapsulation user,  
**I want** CLI to skip private imports,  
**So that** private dependencies aren't exposed in public target interfaces.

**Acceptance Criteria:**
- Detect import modifiers: `private`, `internal`, `public`, `package`
- Current logic: skip `private` imports (keep public/internal/package)
- Test: file with `private import Foo` → not in results
- Test: file with `public import Bar` → in results
- Document: "Private imports excluded from output"

## User Story 5.3: Complex Import Path Handling

**As a** developer,  
**I want** CLI to extract only top-level module names,  
**So that** `import A.B.C` is captured as "A" (correct for SPM).

**Acceptance Criteria:**
- Handle multi-level imports: `import ComposableArchitecture.Testing`
- Extract: first segment = "ComposableArchitecture"
- Deduplicate: `import A` + `import A.B.C` → ["A"]
- Test: various import paths return first segment only

## User Story 5.4: Comment Ignoring

**As a** code analyzer,  
**I want** to ignore "import" strings in comments,  
**So that** disabled imports or examples don't pollute results.

**Acceptance Criteria:**
- `// import Foo` → ignored
- `/* import Bar */` → ignored
- `""" import Baz """` (string literals) → ignored
- Only syntactic ImportDecl statements included
- Test: file with commented imports → not in results
- Test: import in string literal → not in results

## User Story 5.5: Conditional Compilation Handling

**As a** cross-platform developer,  
**I want** CLI to handle #if/#else conditionals,  
**So that** platform-specific imports are all collected.

**Acceptance Criteria:**
- Parse `#if os(iOS)` blocks → extract imports inside
- Handle `#if DEBUG` → extract imports
- Collect from all branches (union of all imports)
- Test: different imports in #if iOS vs #if macOS → both collected
- Test: #if/#else alternation → all imported

## User Story 5.6: Comprehensive Unit Tests

**As a** maintainer,  
**I want** >85% test coverage for GetImportVisitor,  
**So that** edge cases are caught + documented.

**Acceptance Criteria:**
- Test file: `Tests/PackageGeneratorCLITests/GetImportVisitorTests.swift`
- Test cases (minimum):
  - Empty file → no imports
  - Single import → captured
  - Multiple imports → all captured
  - Duplicate imports → deduplicated
  - `import Foundation` → captured
  - `import A.B.C` → captures "A"
  - `public import Foo` → captured
  - `private import Bar` → skipped
  - `@_exported import Baz` → marked as reexported
  - Imports in comments → ignored
  - Imports in strings → ignored
  - #if conditional → all branches collected
  - Invalid syntax → parse error (doesn't crash)
- Coverage report shows >85% of GetImportVisitor covered
- Each test has clear name + documentation

## User Story 5.7: Error Case Testing

**As a** robustness engineer,  
**I want** tests for invalid/malformed Swift code,  
**So that** CLI gracefully handles bad files.

**Acceptance Criteria:**
- Test: syntactically invalid Swift → parse error (not crash)
- Test: file with only comments → succeeds, no imports
- Test: incomplete import statement → handled gracefully
- Test: mixed valid + invalid syntax → valid parts extracted
- Result: 0 crashes on 100 malformed files

## User Story 5.8: File Pattern Exclusion

**As a** user,  
**I want** to exclude files by glob pattern,  
**So that** I can skip test fixtures, generated code, build artifacts.

**Acceptance Criteria:**
- Add `--exclude-patterns <pattern>` (repeatable)
- Glob patterns supported:
  - `**/__Snapshots__/**` → exclude directory
  - `**/Generated/**` → exclude all generated
  - `*.tmp.swift` → exclude temporary files
  - `Tests/**` → exclude tests (optional)
- Default always-excluded:
  - `.build/`
  - `.swiftpm/`
  - `DerivedData/`
  - `.git/`
- Applied during file discovery (before parsing)
- Log excluded count: `[INFO] Excluded 12 files via patterns`
- Test: exclude pattern works correctly

## User Story 5.9: Large File Handling

**As a** builder of large targets,  
**I want** CLI to handle 10,000+ line files efficiently,  
**So that** no timeouts or memory issues occur.

**Acceptance Criteria:**
- Test: parse file with 10,000+ lines → completes in <5s
- Memory usage: reasonable (< 100MB for 100 large files)
- No stack overflow or recursion limits hit
- Extract imports correctly from large files
- Benchmark + document performance on large files

## User Story 5.10: Unicode + Special Characters

**As a** international developer,  
**I want** CLI to handle source files with UTF-8 encoding,  
**So that** non-ASCII code works correctly.

**Acceptance Criteria:**
- Parse file with UTF-8 characters in comments → works
- Parse file with non-ASCII identifiers → works
- Test: file with emoji in comments → no crash, imports extracted
- Document: "UTF-8 encoding required, other encodings not supported"

---

# Epic 6: Observability & Diagnostics

**Description:** Add rich diagnostics output, metrics collection, structured logging for debugging, JSON diagnostic block in output.

## User Story 6.1: JSON Diagnostic Output Block

**As a** plugin developer,  
**I want** detailed diagnostic info beyond just imports,  
**So that** I can report issues to user clearly.

**Acceptance Criteria:**
- Extend output to include diagnostic block:
  ```json
  {
    "targets": [...],
    "diagnostics": {
      "total_files_discovered": 150,
      "total_files_parsed": 145,
      "parse_errors": 5,
      "parse_warnings": 3,
      "elapsed_ms": 2340,
      "max_concurrent_tasks_used": 8,
      "cache_hits": 0,
      "cache_misses": 145
    }
  }
  ```
- Plugin can extract diagnostics + display to user
- Metrics useful for debugging performance

## User Story 6.2: Parse Error Reporting

**As a** debugger,  
**I want** detailed error information for each failed file,  
**So that** I can understand and fix parse failures.

**Acceptance Criteria:**
- For each file parse error, collect:
  - File path
  - Error reason (syntax error, permission denied, etc.)
  - Line/column if available
  - Error formatted as string
- Include in output warnings array
- Log: `[WARN] Parse error in Sources/Core/Models.swift - unexpected token`
- Plugin can display to user with file/line context

## User Story 6.3: Structured Logging for Debugging

**As a** debugger,  
**I want** JSON-formatted logs for structured analysis,  
**So that** I can parse + analyze extraction traces programmatically.

**Acceptance Criteria:**
- Add `--log-format <text|json>` flag (default: text)
- JSON format logs:
  ```json
  {
    "timestamp": "2026-05-01T12:00:00.123Z",
    "level": "info",
    "message": "Parsed file",
    "context": {
      "target": "Core",
      "file": "Sources/Core/Models.swift",
      "imports_found": 3,
      "duration_ms": 45
    }
  }
  ```
- Can pipe to external tools (jq, splunk, datadog, etc.)
- Text format for human readability (default, backward compat)
- Test: both formats work + parse correctly

## User Story 6.4: Performance Metrics Export

**As a** performance analyst,  
**I want** detailed timing information for each parse task,  
**So that** I can identify bottleneck files.

**Acceptance Criteria:**
- Collect per-file metrics:
  - File path
  - Parse time (ms)
  - Imports count
  - Reexports count
- Export with `--metrics-output <file>` flag (optional JSON file)
- Metrics file format:
  ```json
  {
    "files": [
      {
        "path": "Sources/Core/Models.swift",
        "parse_time_ms": 45,
        "imports": 3,
        "reexports": 1
      }
    ]
  }
  ```
- Can analyze slowest files: sort by parse_time_ms DESC

## User Story 6.5: Environment Info Logging

**As a** troubleshooter,  
**I want** CLI to log system/environment info,  
**So that** I can diagnose platform-specific issues.

**Acceptance Criteria:**
- Log on startup (debug level):
  - Swift version (swift --version)
  - OS + architecture (macOS 12.0 arm64)
  - Processor count
  - Memory available
  - Working directory
- Format: `[DEBUG] Environment: Swift 6.2, macOS 12.0 arm64, 8 cores, /Users/me/project`
- Test: logs contain correct environment info

---

# Epic 7: Deployment & Distribution

**Description:** Improve build + distribution process, add version management, support multiple platforms, automate releases via GitHub Actions.

## User Story 7.1: Multi-Platform Binary Builds

**As a** Apple Silicon user,  
**I want** native CLI binary for ARM64,  
**So that** I don't need Rosetta translation layer.

**Acceptance Criteria:**
- Build CLI for both platforms:
  - `arm64-apple-macosx` (Apple Silicon M1/M2+)
  - `x86_64-apple-macosx` (Intel Macs)
- Both binaries in release `.artifactbundle`
- Plugin auto-selects correct binary at runtime via `PackagePlugin.findBinary()`
- Each binary performs identically
- Release notes specify which binary for which platform

## User Story 7.2: Binary Cross-Compilation Script

**As a** release engineer,  
**I want** automated cross-compilation script,  
**So that** I don't manually build each architecture.

**Acceptance Criteria:**
- Update `build.sh`:
  - Detects current arch
  - Cross-compiles to both architectures
  - Creates universal binary (optional): `lipo`
  - Or separate binaries: `cli-arm64`, `cli-x86_64`
  - Signs + notarizes each binary
  - Packages into `.artifactbundle`
- Script is deterministic (same source → same binary)
- Document: "Build process" in README

## User Story 7.3: Version Management

**As a** maintainer,  
**I want** CLI version baked into binary,  
**So that** plugin can verify compatibility.

**Acceptance Criteria:**
- Add `--version` flag to CLI
- Output format: `package-generator-cli version 1.0.0 (Swift 6.2, macOS 12+)`
- Hardcoded version in Package.swift: `let cliVersion = "1.0.0"`
- Version tagged in git: `v1.0.0` matches code version
- Plugin can query version + log it
- Document: "CLI is compatible with plugin v1.x"

## User Story 7.4: Checksum Generation

**As a** plugin maintainer,  
**I want** checksums for each binary,  
**So that** plugin Package.swift can verify integrity.

**Acceptance Criteria:**
- After build: `sha256sum` each binary
- Output: `8eb833ab6ae853c82f67657c1c8fd27cbcbe30dfc7667893fe2a17a9a72622fd`
- Include in release notes
- Plugin Package.swift references checksum:
  ```swift
  .binaryTarget(
    name: "package-generator-cli",
    url: "https://github.com/.../releases/download/v1.0.0/artifact.zip",
    checksum: "8eb833ab6ae853c82f67657c1c8fd27cbcbe30dfc7667893fe2a17a9a72622fd"
  )
  ```

## User Story 7.5: Artifact Bundle Creation

**As a** distribution manager,  
**I want** CLI packaged in standardized `.artifactbundle`,  
**So that** SPM can easily consume it.

**Acceptance Criteria:**
- `.artifactbundle` structure:
  ```
  package-generator-cli-1.0.0.artifactbundle/
  ├── Info.plist (metadata)
  └── package-generator-cli-arm64-apple-macosx/
      └── bin/package-generator-cli
  └── package-generator-cli-x86_64-apple-macosx/
      └── bin/package-generator-cli
  ```
- `Info.plist` specifies version, platform, binary path
- Plugin can extract + use binary
- Document: ".artifactbundle format" in README

## User Story 7.6: GitHub Release Workflow

**As a** release automation,  
**I want** GitHub Actions workflow for releases,  
**So that** releases are fully automated on tag.

**Acceptance Criteria:**
- Workflow trigger: git tag `v*` pushed
- Steps:
  1. Checkout code
  2. Build binaries (cross-compile)
  3. Generate checksums
  4. Create `.artifactbundle`
  5. Create GitHub release with binaries
  6. Output checksum for plugin maintainer
- Workflow file: `.github/workflows/release.yml`
- Document: "Release process" + how to tag

## User Story 7.7: Release Notes Generation

**As a** user,  
**I want** clear release notes with changes,  
**So that** I know what's new + whether to upgrade.

**Acceptance Criteria:**
- Release notes template:
  ```
  ## v1.0.0 - 2026-05-01
  
  ### ✨ New Features
  - Parallel file parsing (3-4x faster)
  - Optional disk caching
  - Swift 6 concurrency support
  
  ### 🐛 Bug Fixes
  - Fixed crash on invalid imports
  - Improved error handling
  
  ### 🔧 Internal
  - Removed Files library dependency
  - Added comprehensive unit tests
  
  ### Download
  - [arm64-apple-macosx](...)
  - [x86_64-apple-macosx](...)
  
  ### Checksums
  - arm64: 8eb833ab...
  - x86_64: 7fa722ac...
  ```
- Include upgrade guide: "Plugin compatibility: v2.0+ required"

## User Story 7.8: Version Compatibility Matrix

**As a** integrator,  
**I want** clear documentation of CLI + plugin compatibility,  
**So that** I know which versions work together.

**Acceptance Criteria:**
- Document in README: compatibility matrix
  ```
  | CLI Version | Plugin Version | Compatible |
  |-------------|----------------|------------|
  | 1.0.0       | 2.0+           | ✅ Yes     |
  | 0.6.x       | 1.x            | ✅ Yes     |
  | 0.5.x       | 1.x            | ❌ No      |
  ```
- Update matrix with each release
- Plugin MIGRATION.md references matrix

## User Story 7.9: Binary Signing + Notarization

**As a** security officer,  
**I want** binaries code-signed + notarized,  
**So that** macOS allows execution without warnings.

**Acceptance Criteria:**
- Each binary: Apple code signing (developer certificate)
- Notarize with Apple: verify not malware
- Staple notarization to binary
- Build script automates: `codesign` + `xcrun notarytool`
- Release notes: "All binaries signed + notarized"
- Users can verify: `codesign -v binary`

## User Story 7.10: Homebrew/Package Manager Distribution (Optional)

**As a** CLI user,  
**I want** to install via `brew install package-generator-cli`,  
**So that** I don't manually download binaries.

**Acceptance Criteria:**
- Create Homebrew formula (optional future work)
- Formula points to GitHub release
- `brew install mackoj/tools/package-generator-cli`
- Also consider: MacPorts, direct SPM support
- Document alternative install methods in README

---

# Implementation Roadmap

## Phase 1: Stability (High Impact, Low Risk) — 2-3 weeks
- Epic 1: Dependencies + error handling (9 stories)
- Epic 5.2: Unit tests for GetImportVisitor
- Estimated effort: 80 hours
- Key metric: >85% coverage, zero crashes

## Phase 2: Performance (Medium Impact, Medium Risk) — 3-4 weeks
- Epic 2: Parallelization + caching (9 stories)
- Epic 6: Observability (5 stories)
- Estimated effort: 120 hours
- Key metric: 3-4x speedup, >40% cache hit rate

## Phase 3: Modern Patterns (Low Impact, Medium Risk) — 2-3 weeks
- Epic 4: Swift 6 concurrency (8 stories)
- Epic 5.1: Re-exported imports (3 stories)
- Estimated effort: 90 hours
- Key metric: Strict concurrency, zero warnings

## Phase 4: Decoupling & Distribution (Low Impact, Low Risk) — 2-3 weeks
- Epic 3: Generic I/O (7 stories)
- Epic 7: Deployment (10 stories)
- Estimated effort: 100 hours
- Key metric: Standalone CLI, multi-arch, automated releases

---

# Total Effort Estimate

| Phase | Duration | Effort (hours) | Stories | Priority |
|-------|----------|----------------|---------|----------|
| **Phase 1** | 2-3 weeks | 80 | 10 | 🔴 NOW |
| **Phase 2** | 3-4 weeks | 120 | 14 | 🔴 SOON |
| **Phase 3** | 2-3 weeks | 90 | 11 | 🟡 AFTER-1 |
| **Phase 4** | 2-3 weeks | 100 | 17 | 🟢 LATER |
| **TOTAL** | **~3-4 months** | **~390** | **52** | - |

---

# Success Metrics by Phase

### Phase 1
- ✅ Zero `fatalError()` calls in codebase
- ✅ Unit test coverage > 85%
- ✅ No `Files` library dependency
- ✅ Graceful error handling + exit codes

### Phase 2
- ✅ 3-4x faster parse on 100+ file project
- ✅ Cache hit rate > 40% on local iterations
- ✅ Disk cache effective across invocations
- ✅ Batch mode reduces CLI invocations by 50x

### Phase 3
- ✅ Swift 6 strict concurrency: zero warnings
- ✅ All types `Sendable` + safe
- ✅ Re-exported imports detected + tested
- ✅ Comprehensive edge case coverage (>90% tests)

### Phase 4
- ✅ CLI usable standalone (not coupled to plugin)
- ✅ Binaries for both arm64 + x86_64
- ✅ Release automation 100% hands-off (GitHub Actions)
- ✅ Version compatibility matrix updated

---

# Dependencies & Risks

### Dependencies
- Phase 2 depends on Phase 1 (error handling must be solid first)
- Phase 3 can run parallel with Phase 2 (separate concerns)
- Phase 4 depends on Phase 1-3 (stabilization first)

### Risks
- **Risk: Concurrency complexity** → Mitigate: Use established Swift patterns, thorough testing
- **Risk: Performance regression** → Mitigate: Benchmark before/after each phase, keep metrics
- **Risk: Binary distribution** → Mitigate: Test on real machines (not VMs), sign + notarize properly
- **Risk: Backward compatibility break** → Mitigate: Adapter layer + version checking

---

# References

- Current CLI: `/Users/mac-JMACKO01/Developer/PackageGeneratorCLI`
- V2 Plugin: `/Users/mac-JMACKO01/Developer/PackageGeneratorPlugin` (consumer)
- Swift Concurrency: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- Sendable: https://developer.apple.com/documentation/swift/sendable
- TaskGroup: https://developer.apple.com/documentation/swift/withtaskgroup(of:returning:body:)
- ArgumentParser: https://github.com/apple/swift-argument-parser
- Swift 6 Migration: https://www.swift.org/migration/

---

# Epic 8: Structured Logging with OSLog

**Description:** Replace all `print()` / `logInfo()` / `logWarning()` calls with Apple's `os.Logger`, giving every log entry a **subsystem**, **category**, and **level**. OSLog messages appear in Console.app and `log stream` without any extra tooling, cost near-zero when the level is below threshold, and support privacy annotations so file paths aren't leaked in system logs.

**Why this matters for debugging:**
- `print()` goes to stdout (consumed by the plugin, not a log)
- Current code mixes diagnostic output with JSON output on the same stream
- OSLog separates concerns: JSON → stdout, diagnostics → unified logging system
- Console.app filtering by subsystem/category makes debugging parallel runs trivial

---

## User Story 8.1: Logger Infrastructure

**As a** developer,  
**I want** a central `Loggers` namespace that vends pre-configured `os.Logger` instances per category,  
**So that** every log line has a consistent subsystem + category without boilerplate.

**Acceptance Criteria:**
- Create `Sources/PackageGeneratorCLI/Logging/Loggers.swift`:
  ```swift
  import OSLog

  enum Loggers {
    static let subsystem = "com.mackoj.PackageGeneratorCLI"

    static let fileDiscovery  = Logger(subsystem: subsystem, category: "FileDiscovery")
    static let importParsing  = Logger(subsystem: subsystem, category: "ImportParsing")
    static let concurrency    = Logger(subsystem: subsystem, category: "Concurrency")
    static let configuration  = Logger(subsystem: subsystem, category: "Configuration")
    static let output         = Logger(subsystem: subsystem, category: "Output")
    static let lifecycle      = Logger(subsystem: subsystem, category: "Lifecycle")
  }
  ```
- Subsystem matches the bundle/tool identifier: `com.mackoj.PackageGeneratorCLI`
- One `Logger` per logical area (not one per file)
- No global mutable state — `Logger` is a value type, safe to use from any actor

## User Story 8.2: Log Level Semantics

**As a** debugger,  
**I want** each log call to use the semantically correct OSLog level,  
**So that** Console.app filtering shows only relevant noise.

**Acceptance Criteria:**

| Level | When to use | OSLog call |
|-------|-------------|------------|
| `debug` | Fine-grained detail (per-file paths, import counts) — omitted in release by default | `logger.debug(...)` |
| `info` | Normal progress milestones (target started, target done) | `logger.info(...)` |
| `notice` | Interesting events worth preserving in system log (cache hit, skip reason) | `logger.notice(...)` |
| `warning` | Recoverable unexpected state (self-import filtered, parse failed for one file) | `logger.warning(...)` |
| `error` | Operation failed but CLI may continue (one target failed, others succeed) | `logger.error(...)` |
| `fault` | Unrecoverable logic error that should never happen (programmer error) | `logger.fault(...)` |

- No `logger.critical(...)` for normal errors — reserve `fault` for invariant violations
- Every existing `logInfo()` / `logWarning()` call mapped to correct level in acceptance test

## User Story 8.3: Replace Print-Based Logging

**As a** maintainer,  
**I want** all `print()`, `logInfo()`, and `logWarning()` calls replaced with `os.Logger`,  
**So that** diagnostic messages no longer contaminate stdout (which carries the JSON output).

**Current state (cli.swift):**
```swift
private func logInfo(_ message: String) {
  print("[package-generator-cli] \(message)")
}
private func logWarning(_ message: String) {
  print("[package-generator-cli WARNING] \(message)")
}
```

**Target state:**
```swift
// FileDiscovery context
Loggers.fileDiscovery.info("Processing target module \"\(targetModuleName, privacy: .public)\"")
Loggers.fileDiscovery.warning("Filtered self-import \"\(targetModuleName, privacy: .public)\" from \(file.lastPathComponent, privacy: .public)")
Loggers.importParsing.warning("Failed to extract imports from \(file.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
```

**Acceptance Criteria:**
- Zero `print()` calls in non-test source files (except intentional stdout output)
- Zero `logInfo()` / `logWarning()` private methods
- JSON output still goes to stdout via `FileHandle.standardOutput`
- Diagnostic output goes only to unified logging system
- `log stream --predicate 'subsystem == "com.mackoj.PackageGeneratorCLI"'` shows all CLI messages

## User Story 8.4: Privacy Annotations

**As a** privacy-conscious user,  
**I want** file paths and user-identifiable data tagged with correct OSLog privacy levels,  
**So that** system logs don't leak sensitive filesystem layout to other processes.

**Acceptance Criteria:**
- File paths: `.private` (contains username, project structure)
  ```swift
  logger.debug("Scanning \(file.path, privacy: .private)")
  ```
- Module/target names: `.public` (safe — these are code identifiers, not user data)
  ```swift
  logger.info("Processing target \(targetModuleName, privacy: .public)")
  ```
- Error messages: `.public` (already sanitized by `localizedDescription`)
- Import names: `.public`
- Rule documented in `CONTRIBUTING.md`: new log lines must annotate string interpolations

## User Story 8.5: Verbose Flag Integration

**As a** CLI user,  
**I want** `--verbose` to control what appears in terminal output (not OSLog),  
**So that** I can see detailed progress without enabling system-wide logging.

**Background:** OSLog messages are always written to the unified logging system at their level. The `--verbose` flag should additionally print a human-readable summary to stderr for terminal users who don't have Console.app open.

**Acceptance Criteria:**
- `--verbose` flag causes key `info` + `debug` messages to also print to **stderr** (not stdout):
  ```swift
  if verbose {
    fputs("[package-generator-cli] \(message)\n", stderr)
  }
  Loggers.lifecycle.info("\(message, privacy: .public)")
  ```
- Without `--verbose`: terminal shows nothing (quiet mode); OSLog still captures everything
- With `--verbose`: stderr shows progress; stdout carries only JSON output
- `--verbose` does **not** change what gets written to the unified logging system (OSLog level controls that)

## User Story 8.6: Per-Target + Per-File Structured Log Entries

**As a** debugger diagnosing a specific target,  
**I want** structured log entries carrying target name, file path, and import count as metadata,  
**So that** I can filter Console.app to a single target without grepping log text.

**Acceptance Criteria:**
- Use OSLog's structured interpolation (Swift string interpolation evaluated lazily):
  ```swift
  Loggers.importParsing.debug(
    "Parsed \(file.lastPathComponent, privacy: .public): \(imports.count) imports [\(imports.joined(separator: ", "), privacy: .public)]"
  )
  Loggers.importParsing.info(
    "Target \(targetName, privacy: .public) complete: \(fileCount) files, \(importCount) unique imports"
  )
  ```
- `log show --predicate 'subsystem == "com.mackoj.PackageGeneratorCLI" AND category == "ImportParsing"'` filters to parse events only
- Each concurrent task logs its own target name (task-scoped, no mixing)

## User Story 8.7: Lifecycle + Run Summary Log

**As a** performance debugger,  
**I want** structured start/finish log entries with elapsed time and summary counts,  
**So that** I can compare runs and spot regressions in Console.app.

**Acceptance Criteria:**
- On startup, log:
  ```swift
  Loggers.lifecycle.info(
    "package-generator-cli started: \(targets.count) targets, packageDir=\(packageDir.lastPathComponent, privacy: .public)"
  )
  ```
- On completion, log:
  ```swift
  Loggers.lifecycle.info(
    "package-generator-cli finished: \(parsedCount) targets parsed, \(skippedCount) skipped, elapsed=\(elapsed, format: .fixed(precision: 2))s"
  )
  ```
- On fatal error, log with `.fault`:
  ```swift
  Loggers.lifecycle.fault("Unrecoverable error: \(error.localizedDescription, privacy: .public)")
  ```
- Elapsed time measured with `ContinuousClock` (not `Date`)
- All summary values logged as OSLog metadata (not embedded in free-form string)

## User Story 8.8: Concurrency-Aware Logging

**As a** concurrent system,  
**I want** log entries from task-group workers to include the task name and target,  
**So that** interleaved log messages from parallel parse tasks can be untangled in Console.app.

**Acceptance Criteria:**
- Each task logs its name (from Swift 6.2 task naming in Story 4.5):
  ```swift
  Loggers.concurrency.debug("Task \(Task.name ?? "unnamed", privacy: .public) started for \(targetName, privacy: .public)")
  ```
- Log entries carry implicit `os_activity` context — no manual activity ID needed
- Concurrency logger category: `"Concurrency"` (separate from `"ImportParsing"` so noise is filterable)
- Test: 10 parallel tasks, verify each log line identifies its own task name in the message

## User Story 8.9: Log Testing

**As a** quality engineer,  
**I want** unit tests that assert on key log events without depending on the unified logging system,  
**So that** regressions in diagnostic coverage are caught in CI.

**Acceptance Criteria:**
- Introduce `LogSink` protocol:
  ```swift
  protocol LogSink: Sendable {
    func log(level: LogLevel, category: String, message: String)
  }

  enum LogLevel: Sendable { case debug, info, notice, warning, error, fault }
  ```
- `OSLogSink` wraps real `os.Logger` (production)
- `MockLogSink` collects entries into array (tests)
- Tests inject `MockLogSink` and assert:
  - `.warning` emitted when self-import filtered
  - `.error` emitted when parse failure
  - `.info` emitted for lifecycle start/finish
  - No `.fault` emitted in happy path

