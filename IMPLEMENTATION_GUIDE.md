# CLI v2 Implementation Guide

Quick reference for starting the CLI v2 rewrite.

## Document Structure

1. **UserStories.md** (1300+ lines)
   - 66 detailed user stories organized by 7 epics
   - Each story has acceptance criteria
   - Implementation roadmap + effort estimates
   - Dependencies + risk analysis

2. **ROADMAP.md** (5.5 KB)
   - 4-phase implementation plan
   - Priority matrix
   - Quick overview + key changes

3. **This file** (you are here)
   - Quick reference for starting work

---

## The 7 Epics at a Glance

| Epic | Phase | Stories | Focus | Duration |
|------|-------|---------|-------|----------|
| **1: Dependencies & Error Handling** | 1 | 9 | Remove Files lib, proper errors | 2 weeks |
| **2: Performance** | 2 | 9 | Parallelization + caching | 3 weeks |
| **3: Decouple** | 4 | 7 | Generic I/O schemas | 2 weeks |
| **4: Swift 6** | 3 | 8 | Actor isolation, Sendable | 2 weeks |
| **5: Enhanced Imports** | 1,3 | 10 | Re-exports, tests, edge cases | Parallel |
| **6: Observability** | 2 | 5 | Metrics, structured logging | 1 week |
| **7: Deployment** | 4 | 10 | Multi-platform, automation | 2 weeks |

**Total: 52 user stories, ~390 hours, 3-4 months**

---

## Where to Start (Phase 1 - Highest Priority)

### Step 1: Epic 1.1 - Remove Files Library
1. Open `Sources/PackageGeneratorCLI/cli.swift`
2. Replace `Files.Folder(path:)` → `FileManager.default`
3. Use `enumerator(atPath:)` for recursion
4. Remove `Files` from Package.swift
5. Test: build + run, same output as before

**Effort: 1-2 days**

### Step 2: Epic 1.2-1.9 - Error Handling
1. Create `enum CLIError: LocalizedError` with 8 cases
2. Replace all `fatalError()` → `throw CLIError.*`
3. Main catches errors + exits with code
4. Logs to stderr, output to stdout
5. Add logging protocol + ConsoleLogger

**Effort: 2-3 days**

### Step 3: Epic 5.2 - Unit Tests
1. Create `Tests/PackageGeneratorCLITests/GetImportVisitorTests.swift`
2. Add 15+ test cases covering edge cases
3. Target >85% coverage of GetImportVisitor
4. Run: `swift test`

**Effort: 2 days**

**Phase 1 Total: ~1 week**

---

## Then Phase 2 - Performance

### Step 4: Epic 2.1 - File Discovery
1. Implement `func discoverSwiftFiles(in:excludingPatterns:) → [URL]`
2. Recursively find `.swift` files
3. Skip `.build/`, `.swiftpm/`, `DerivedData/`
4. Return sorted URLs

**Effort: 1 day**

### Step 5: Epic 2.2 - Parallel Parsing
1. Implement `func parseFilesInParallel(_:maxConcurrent:) async → [ParseResult]`
2. Use `withTaskGroup(of:returning:)` for concurrent tasks
3. Each task: parse one file via `GetImportVisitor`
4. Collect results maintaining order
5. Benchmark: measure 3-4x speedup

**Effort: 2-3 days**

### Step 6: Epic 2.4-2.5 - Caching
1. In-memory cache: always active
2. Disk cache: opt-in via `--use-cache`
3. Cache key: file path + mtime
4. Implement cache invalidation on file change

**Effort: 2 days**

### Step 7: Epic 6 - Observability
1. Add `--log-level` flag + Logger protocol
2. Extend output with diagnostics block
3. Add `--log-format json` option
4. Collect performance metrics per file

**Effort: 2 days**

**Phase 2 Total: ~2 weeks**

---

## Then Phase 3 - Modern Patterns

### Step 8: Epic 4 - Swift 6 Concurrency
1. Create `actor ImportCollector` for thread-safe collection
2. Make types `Sendable` (struct over class)
3. Use `TaskGroup` for structured concurrency
4. Compile with `-strict-concurrency=complete` → zero warnings

**Effort: 2 weeks**

### Step 9: Epic 5.1 - Re-exported Imports
1. Update `GetImportVisitor` to detect `@_exported` modifier
2. Mark re-exported imports separately in output
3. Add tests for re-export detection

**Effort: 1-2 days**

**Phase 3 Total: ~2 weeks**

---

## Finally Phase 4 - Distribution

### Step 10: Epic 3 - Generic I/O
1. Define `GenericInput` + `GenericOutput` schemas (JSON)
2. Decouple CLI from `PackageInformation`
3. Create adapter layer for plugin
4. CLI only knows generic schemas internally

**Effort: 1 week**

### Step 11: Epic 7 - Deployment
1. Update `build.sh` for cross-compilation (arm64 + x86_64)
2. Create `.artifactbundle` with both binaries
3. Setup GitHub Actions workflow for automated releases
4. Add version management + checksums

**Effort: 1-2 weeks**

**Phase 4 Total: ~2-3 weeks**

---

## Testing Strategy

### Unit Tests
- `GetImportVisitorTests`: 15+ test cases for import extraction
- `CLIErrorTests`: error handling paths
- `CacheTests`: in-memory + disk cache
- `ConcurrencyTests`: concurrent safety (TaskGroup, actors)

### Integration Tests
- End-to-end: real Swift project → imports extracted correctly
- Benchmark: measure 3-4x speedup vs current
- Platform: test on both arm64 + x86_64 Macs
- Large files: 10,000+ line files handled efficiently

### Acceptance Criteria Checklist
Use `UserStories.md` - each story lists exact AC. Verify before merging:
```
Story 1.1: [ ] Files lib removed [ ] FileManager used [ ] Compiles [ ] Functionally identical
Story 1.2: [ ] CLIError defined [ ] 8 cases [ ] All errors documented
Story 2.2: [ ] TaskGroup implemented [ ] 3-4x speedup verified [ ] Tests pass
...
```

---

## Git Workflow

```bash
# Phase 1: Create branch
git checkout -b epic/phase-1-stability

# Work story by story
git commit -m "1.1: Remove Files library dependency

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

git commit -m "1.2: Add structured CLIError enum with 8 cases

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

# After all Phase 1 stories complete
git push origin epic/phase-1-stability
# Create PR for review + merge

# Phase 2: New branch
git checkout -b epic/phase-2-performance
# ...repeat
```

---

## Key Files to Modify/Create

### Phase 1
- `Sources/PackageGeneratorCLI/cli.swift` (refactor)
- `Sources/PackageGeneratorCLI/CLIError.swift` (new)
- `Sources/PackageGeneratorCLI/Logger.swift` (new)
- `Tests/PackageGeneratorCLITests/GetImportVisitorTests.swift` (new)

### Phase 2
- `Sources/PackageGeneratorCLI/FileDiscovery.swift` (new)
- `Sources/PackageGeneratorCLI/ConcurrentParser.swift` (new)
- `Sources/PackageGeneratorCLI/ParseCache.swift` (new)
- `Sources/PackageGeneratorCLI/Diagnostics.swift` (new)

### Phase 3
- `Sources/PackageGeneratorCLI/ImportCollector.swift` (new actor)
- Modify `GetImportVisitor` for re-exports
- `Tests/PackageGeneratorCLITests/ReexportTests.swift` (new)

### Phase 4
- `Sources/PackageGeneratorCLI/GenericSchemas.swift` (new)
- `Sources/PackageGeneratorCLI/PluginAdapter.swift` (new)
- `.github/workflows/release.yml` (new)
- Update `build.sh` for cross-compile

---

## Success Checklist

### Phase 1 Complete ✅
- [ ] Zero `fatalError()` in codebase
- [ ] All 10 Phase 1 stories completed + accepted
- [ ] Unit test coverage >85%
- [ ] No `Files` library dependency
- [ ] `swift build` + `swift test` pass

### Phase 2 Complete ✅
- [ ] All 14 Phase 2 stories completed
- [ ] 3-4x speedup measured + benchmarked
- [ ] Cache hit rate >40% on local runs
- [ ] Batch mode works (50 targets in 1 call)
- [ ] Metrics + logging working

### Phase 3 Complete ✅
- [ ] All 11 Phase 3 stories completed
- [ ] `swift build -Xswiftc -strict-concurrency=complete` → zero warnings
- [ ] Re-exports detected + tested
- [ ] All types `Sendable`
- [ ] TaskGroup + actors used correctly

### Phase 4 Complete ✅
- [ ] All 17 Phase 4 stories completed
- [ ] CLI works standalone (not coupled to plugin)
- [ ] Both arm64 + x86_64 binaries build
- [ ] GitHub Actions release workflow working
- [ ] Version compatibility matrix in README

---

## Quick Commands

```bash
# Build
swift build

# Test
swift test

# Test with strict concurrency
swift build -Xswiftc -strict-concurrency=complete

# Format
swift format -i -r Sources/

# Benchmark (after Phase 2)
time ./path/to/cli --input-file inputs.json --output-file outputs.json

# Generate cache metrics (after Phase 2)
CLI_LOG_LEVEL=info ./cli ... 2>&1 | grep "Cache"

# Run with verbose logging
./cli --verbose --input-file inputs.json
```

---

## References

- **Full detailed stories:** See `UserStories.md`
- **High-level overview:** See `ROADMAP.md`
- **Current CLI:** `/Users/mac-JMACKO01/Developer/PackageGeneratorCLI`
- **Plugin consumer:** `/Users/mac-JMACKO01/Developer/PackageGeneratorPlugin`

---

**Ready to start? Begin with Phase 1, Story 1.1. Good luck! 🚀**
