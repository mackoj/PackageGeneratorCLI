import Testing
@testable import PackageGeneratorCLI

struct LogSinkTests {

  // MARK: - MockLogSink basics

  @Test("MockLogSink captures entries at correct level and category")
  func capturesEntry() {
    let sink = MockLogSink()
    sink.log(level: .warning, category: "ImportParsing", message: "test warning")
    #expect(sink.entries.count == 1)
    let entry = sink.entries[0]
    #expect(entry.level == .warning)
    #expect(entry.category == "ImportParsing")
    #expect(entry.message == "test warning")
  }

  @Test("MockLogSink captures multiple entries in order")
  func capturesMultipleEntries() {
    let sink = MockLogSink()
    sink.log(level: .debug,   category: "Concurrency",   message: "started")
    sink.log(level: .info,    category: "Lifecycle",      message: "running")
    sink.log(level: .warning, category: "ImportParsing",  message: "filtered")
    sink.log(level: .error,   category: "ImportParsing",  message: "failed")
    #expect(sink.entries.count == 4)
    #expect(sink.entries.map(\.level) == [.debug, .info, .warning, .error])
  }

  @Test("MockLogSink reset clears all entries")
  func resetClearsEntries() {
    let sink = MockLogSink()
    sink.log(level: .info, category: "Lifecycle", message: "started")
    sink.reset()
    #expect(sink.entries.isEmpty)
  }

  @Test("MockLogSink.first(level:category:) returns correct entry")
  func firstByLevelAndCategory() {
    let sink = MockLogSink()
    sink.log(level: .warning, category: "FileDiscovery", message: "dir missing")
    sink.log(level: .warning, category: "ImportParsing", message: "parse failed")
    let found = sink.first(level: .warning, category: "ImportParsing")
    #expect(found?.message == "parse failed")
  }

  @Test("MockLogSink.entries(at:) filters by level")
  func filtersByLevel() {
    let sink = MockLogSink()
    sink.log(level: .info,    category: "Lifecycle",     message: "start")
    sink.log(level: .warning, category: "ImportParsing", message: "w1")
    sink.log(level: .warning, category: "FileDiscovery", message: "w2")
    sink.log(level: .error,   category: "ImportParsing", message: "err")
    let warnings = sink.entries(at: .warning)
    #expect(warnings.count == 2)
    #expect(warnings.allSatisfy { $0.level == .warning })
  }

  // MARK: - LogLevel

  @Test("LogLevel has all expected cases")
  func logLevelCases() {
    let all = LogLevel.allCases
    #expect(all.contains(.debug))
    #expect(all.contains(.info))
    #expect(all.contains(.notice))
    #expect(all.contains(.warning))
    #expect(all.contains(.error))
    #expect(all.contains(.fault))
  }

  // MARK: - Concurrency safety

  @Test("MockLogSink is safe for concurrent writes")
  func concurrentWrites() async {
    let sink = MockLogSink()
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<100 {
        group.addTask {
          sink.log(level: .debug, category: "Concurrency", message: "msg\(i)")
        }
      }
    }
    #expect(sink.entries.count == 100)
    #expect(sink.entries.allSatisfy { $0.level == .debug })
  }
}
