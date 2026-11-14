# Measuring and profiling

The benchmarks live in `Benchmarks/`, a separate package on
[package-benchmark](https://github.com/ordo-one/package-benchmark), so the CLI never depends on it. They measure the
scanner in `PackageGeneratorCore` on a synthetic package written to a temporary directory: 40 targets with test
targets (2,040 files of about 220 lines, imports at the top, some behind `#if`), a single 500-file target, 100 files
parsed one after the other, and decoding and encoding the plugin's JSON for 2,000 targets. Run everything from the
repository root.

## Measure a change

Save `main`'s numbers before you change code, then compare the same harness after:

```sh
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/before.md
# … change the code …
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/after.md
swift run --package-path Benchmarks -c release p50 .build/before.md .build/after.md
```

`p50` prints a Markdown table of each benchmark's median wall clock and mallocs, before → after, ready for the pull
request. Malloc and retain counts are deterministic; wall clock moves between runs, a lot for the scans, which are
dominated by opening files. Rerun a benchmark before trusting a change under 10%.

- `--filter` takes one regular expression per flag: `--filter 'Scan.*' --filter 'Parse.*'`.
- Each benchmark also reports CPU time, peak resident memory and retains; the full table is in the Markdown output.
- jemalloc: package-benchmark uses it when installed (`brew install jemalloc`); set `BENCHMARK_DISABLE_JEMALLOC=true`
  to build without it, as CI does.

## Profile a benchmark

```sh
Benchmarks/scripts/profile.sh 'Scan package, 2000 files' 25
```

It runs that one benchmark under Instruments' Time Profiler and prints:

- **Self**: the functions the samples were in. `__open` and `getattrlistbulk` are the file system, `validateUTF8`
  is reading a file into a `String`, `Lexer`/`TokenSpec` entries are swift-syntax's parser.
- **Inclusive**: the scanner's and swift-syntax's functions with the most samples under them.

The trace stays in `Benchmarks/.build/profiles/` to open in Instruments.

## What has paid off

The first round, on an Apple silicon Mac (p50, before → after):

| Benchmark | Wall clock | CPU | Mallocs | Retains | Peak memory |
|---|---|---|---|---|---|
| Scan package, 2,040 files | 766.5 → 28.7 ms (26.7x) | 9,169 → 454 ms | 1,529,577 → 153,599 | 10.6M → 254k | 40 → 33 MB |
| Scan target, 500 files | 286.3 → 10.3 ms (27.7x) | 3,563 → 122 ms | 556,049 → 50,173 | 3.88M → 89k | 31 → 25 MB |
| Parse files, 100 sequentially | 91.6 → 4.2 ms (21.7x) | 91.4 → 4.2 ms | 73,551 → 6,101 | 517k → 12k | 17 → 16 MB |
| Decode input JSON, 2,000 targets | 11.4 → 8.2 ms | 11.3 → 8.2 ms | 44,334 → 39,934 | 163k → 149k | 15 → 16 MB |
| Encode output JSON, 2,000 packages | 8.2 → 6.8 ms (unchanged code) | | 19,532 → 19,532 | | 20 → 20 MB |

On a real package (swift-syntax's 26 targets with their tests, 539 files) the release binary went from 0.85 s to
0.07 s of CPU, 60 to 20 ms of wall clock, and 129 to 46 MB peak resident memory, with the same output.

- **Parse only the part of a file that can hold imports.** Every import declaration contains the keyword `import`,
  so none starts after its last occurrence. `ImportRegion` finds the end of the last declaration with a byte scan
  (a backward Horspool search for the word, then trivia, comments and the dotted path) and the parser sees only that
  prefix; a file without the word is not parsed at all. On 23,206 Swift files from package checkouts it parses 8%
  of the bytes and finds exactly the imports a full parse finds (`ImportRegionTests` keeps the tricky cases: imports
  after declarations, the word in strings and nested comments, a path split over lines, `#if`). Building and walking
  the whole syntax tree was over 90% of the time and nearly all the allocations and retains.
- **Read the tree with a `SyntaxVisitor`, not a `SyntaxRewriter`**, and skip the inside of each import: the rewriter
  rebuilt nothing but paid for a rewriting walk of every node.
- **Try the common JSON shape first.** `PackageInformation` decoded each entry as a legacy path string before trying
  the object form, so every modern entry built and threw away a `DecodingError` (10% fewer mallocs).
- Not worth it: walking each target once for both its Swift files and its `Resources` folder. It saved one
  directory walk but moved per-file URL work from the parallel parse tasks onto the serial walk; the scan got no
  faster and allocated more.
- What is left is the file system: about half of the scan's samples are in `__open`, even one file at a time.
