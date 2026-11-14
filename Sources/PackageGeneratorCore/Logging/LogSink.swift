import OSLog
import Foundation

// MARK: - Level

/// Mirrors OSLog levels for testability.
enum LogLevel: String, Sendable, CaseIterable {
  case debug, info, notice, warning, error, fault
}

// MARK: - Protocol

/// Abstraction over logging that enables mock injection in tests.
/// Implementations must be Sendable (called from concurrent contexts).
protocol LogSink: Sendable {
  func log(level: LogLevel, category: String, message: String)
}

// MARK: - OSLogSink

/// Production sink that routes to the unified logging system via os.Logger.
struct OSLogSink: LogSink {
  func log(level: LogLevel, category: String, message: String) {
    let logger = Logger(subsystem: Loggers.subsystem, category: category)
    switch level {
    case .debug:   logger.debug("\(message, privacy: .public)")
    case .info:    logger.info("\(message, privacy: .public)")
    case .notice:  logger.notice("\(message, privacy: .public)")
    case .warning: logger.warning("\(message, privacy: .public)")
    case .error:   logger.error("\(message, privacy: .public)")
    case .fault:   logger.fault("\(message, privacy: .public)")
    }
  }
}

// MARK: - MockLogSink

/// Test-only sink. Collects entries for assertion.
/// Thread-safe via NSLock. @unchecked Sendable because the lock
/// provides the required synchronization the compiler cannot verify.
final class MockLogSink: LogSink, @unchecked Sendable {
  struct Entry: Sendable, Equatable {
    let level: LogLevel
    let category: String
    let message: String
  }

  private let lock = NSLock()
  private var _entries: [Entry] = []

  var entries: [Entry] {
    lock.withLock { _entries }
  }

  func log(level: LogLevel, category: String, message: String) {
    lock.withLock {
      _entries.append(Entry(level: level, category: category, message: message))
    }
  }

  func reset() {
    lock.withLock { _entries.removeAll() }
  }

  /// Convenience: first entry matching level + category, or nil.
  func first(level: LogLevel, category: String) -> Entry? {
    entries.first { $0.level == level && $0.category == category }
  }

  /// Convenience: all entries at a given level.
  func entries(at level: LogLevel) -> [Entry] {
    entries.filter { $0.level == level }
  }
}
