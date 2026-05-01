import Foundation

/// Internal result type for a single parsed Swift file.
/// Sendable because all members are value types.
struct ParseResult: Sendable {
  let file: URL
  let imports: [String]
  let targetModuleName: String
}
