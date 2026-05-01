import OSLog

/// Central namespace for all os.Logger instances.
/// One Logger per logical category — filterable in Console.app by
/// subsystem "com.mackoj.PackageGeneratorCLI" and category.
enum Loggers {
  static let subsystem = "com.mackoj.PackageGeneratorCLI"

  /// File discovery and directory enumeration events.
  static let fileDiscovery = Logger(subsystem: subsystem, category: "FileDiscovery")

  /// Per-file and per-target import extraction events.
  static let importParsing = Logger(subsystem: subsystem, category: "ImportParsing")

  /// Task group creation, concurrency limits, task lifecycle.
  static let concurrency = Logger(subsystem: subsystem, category: "Concurrency")

  /// Input loading and configuration parsing.
  static let configuration = Logger(subsystem: subsystem, category: "Configuration")

  /// JSON encoding and output writing.
  static let output = Logger(subsystem: subsystem, category: "Output")

  /// CLI start, finish, elapsed time, fatal errors.
  static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
}
