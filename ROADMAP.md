# PackageGeneratorCLI v2 Improvement Roadmap

## Quick Overview

Current CLI works but has scalability gaps. This roadmap modernizes it across 7 epics organized in 4 phases.

**Current State:**
- ✅ Extracts imports via SwiftSyntax
- ✅ JSON I/O for plugin consumption
- ❌ External dependency (`Files` library)
- ❌ No parallelization (slow on large projects)
- ❌ No error handling (crashes on errors)
- ❌ Tightly coupled to plugin models
- ❌ Old concurrency patterns (not Swift 6)
- ❌ Limited import detection (no re-exports)

## 4 Implementation Phases

### Phase 1: Stability ⚡ (High Impact, Low Risk) — 2-3 weeks
**Goal:** Remove deps, add proper error handling, add tests

Epics:
- **Epic 1** (Dependency Refactoring)
  - Remove `Files` library → use native `FileManager`
  - Add structured error handling + exit codes
  - Configurable logging (error/warning/info/debug)
  
- **Epic 5.2** (Unit Tests)
  - 85%+ coverage for `GetImportVisitor`
  - Edge cases: comments, string literals, modifiers, conditionals

**Deliverable:** Lean, testable, no crashes, single binary

### Phase 2: Performance 🚀 (Medium Impact, Medium Risk) — 3-4 weeks
**Goal:** 3-4x speedup via parallelization + caching

Epics:
- **Epic 2.1** (Parallel File Parsing)
  - TaskGroup for concurrent parsing
  - CPU-core-aware concurrency tuning
  - Result merge + deterministic ordering
  
- **Epic 2.2** (Parse Caching)
  - In-memory cache (always active)
  - Optional disk cache (opt-in)
  - Hit rate logging
  
- **Epic 2.3** (Batch Mode)
  - Multi-input support
  - Single batch call vs 50 CLI invocations

**Deliverable:** 3-4x faster on large projects, cache hits logged

### Phase 3: Modern Patterns 🎯 (Low Impact, Medium Risk) — 2-3 weeks
**Goal:** Swift 6 best practices, re-export handling

Epics:
- **Epic 4** (Swift 6 Concurrency)
  - Actor-based import collection
  - Sendable conformance
  - Structured task groups + cancellation
  
- **Epic 5.1** (Re-exported Imports)
  - `@_exported import` detection
  - Metadata tagging
  
- **Epic 5.3** (File Exclusion)
  - Glob patterns
  - Default excludes (`.build/`, etc.)

**Deliverable:** Strict concurrency compliance, re-exports detected

### Phase 4: Decoupling & Distribution 📦 (Low Impact, Low Risk) — 2 weeks
**Goal:** Standalone tool + multi-platform releases

Epics:
- **Epic 3** (Generic I/O)
  - Decouple from `PackageInformation`
  - Generic input/output schemas
  - Adapter layer for plugin
  
- **Epic 6** (Observability)
  - JSON diagnostic output
  - Structured logging (JSON/text)
  
- **Epic 7** (Deployment)
  - Multi-platform binaries (arm64 + x86_64)
  - Version management
  - GitHub Actions automation

**Deliverable:** Standalone CLI, multi-arch binaries, automated releases

---

## Priority Matrix

| Epic | Phase | Impact | Risk | Effort | Priority |
|------|-------|--------|------|--------|----------|
| **1: Dependencies** | 1 | High | Low | 2 days | 🔴 NOW |
| **2.1: Parallelization** | 2 | High | Medium | 5 days | 🔴 SOON |
| **4: Swift 6** | 3 | Medium | Medium | 1 week | 🟡 AFTER-1 |
| **3: Decouple** | 4 | Low | Low | 1 week | 🟢 LATER |
| **5: Enhanced** | Scattered | Medium | Low | 2 weeks | 🟡 PARALLEL |
| **6: Observability** | 2 | Medium | Low | 3 days | 🟡 PARALLEL |
| **7: Deployment** | 4 | Low | Low | 1 week | 🟢 LATER |

---

## Known Issues Fixed

1. ✅ **Dependency bloat** → Remove `Files` library (Epic 1)
2. ✅ **Crashes on error** → Proper error handling + exit codes (Epic 1)
3. ✅ **Slow parsing** → Parallelize + cache (Epic 2)
4. ✅ **Plugin tight coupling** → Generic schemas (Epic 3)
5. ✅ **Weak logging** → Structured + configurable (Epic 1, 6)
6. ✅ **No concurrency safety** → Actors + Sendable (Epic 4)
7. ✅ **Missing edge cases** → Unit tests + re-exports (Epic 5)
8. ✅ **Single-platform binaries** → Multi-arch (Epic 7)
9. ✅ **Manual releases** → GitHub Actions (Epic 7)
10. ✅ **No import filtering** → (stays in plugin, keeps CLI simple)

---

## Metrics to Track

**Phase 1 Success:**
- [ ] Zero `fatalError()` in codebase
- [ ] Unit test coverage > 85%
- [ ] No external file library

**Phase 2 Success:**
- [ ] 3-4x faster on 100+ file project
- [ ] Cache hit rate > 40%
- [ ] Disk cache effective

**Phase 3 Success:**
- [ ] Swift 6 strict concurrency: 0 warnings
- [ ] All types Sendable
- [ ] Re-exports detected in tests

**Phase 4 Success:**
- [ ] CLI standalone (non-plugin tests pass)
- [ ] Both arm64 + x86_64 binaries
- [ ] Releases fully automated

---

## Detailed Epic Docs

Full user stories with acceptance criteria: → see `UserStories.md`

Quick links:
- [Epic 1: Dependencies & Error Handling](UserStories.md#epic-1-dependency-refactoring--error-handling)
- [Epic 2: Parallelization & Caching](UserStories.md#epic-2-performance-optimization-parallelization--caching)
- [Epic 3: Generic I/O](UserStories.md#epic-3-decouple-from-plugin-models--generic-io)
- [Epic 4: Swift 6](UserStories.md#epic-4-swift-6-concurrency--modern-patterns)
- [Epic 5: Enhanced Imports & Tests](UserStories.md#epic-5-enhanced-import-detection--testing)
- [Epic 6: Observability](UserStories.md#epic-6-observability--diagnostics)
- [Epic 7: Deployment](UserStories.md#epic-7-deployment--distribution)

---

## How to Use This Roadmap

1. **Phase 1 first** (highest ROI, lowest risk)
2. **Parallelize Phase 2 + Phase 5 work** (testing while building perf)
3. **Phase 3 after 2** (benefits from cleaner architecture)
4. **Phase 4 last** (polish after core stable)

Each phase has clear acceptance criteria + testable outcomes. Start with Epic 1, then Epic 2.1 (parallelization).
