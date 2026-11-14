import OSLog

/// Central namespace for all os.Logger instances.
/// One Logger per logical category — filterable in Console.app by
/// subsystem "com.mackoj.PackageGeneratorCLI" and category.
package enum Loggers {
  package static let subsystem = "com.mackoj.PackageGeneratorCLI"

  /// File discovery and directory enumeration events.
  package static let fileDiscovery = Logger(subsystem: subsystem, category: "FileDiscovery")

  /// Per-file and per-target import extraction events.
  package static let importParsing = Logger(subsystem: subsystem, category: "ImportParsing")

  /// Task group creation, concurrency limits, task lifecycle.
  package static let concurrency = Logger(subsystem: subsystem, category: "Concurrency")

  /// Input loading and configuration parsing.
  package static let configuration = Logger(subsystem: subsystem, category: "Configuration")

  /// JSON encoding and output writing.
  package static let output = Logger(subsystem: subsystem, category: "Output")

  /// CLI start, finish, elapsed time, fatal errors.
  package static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
}
