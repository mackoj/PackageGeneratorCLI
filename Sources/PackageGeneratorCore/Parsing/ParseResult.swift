import Foundation

/// The result type for a single parsed Swift file.
/// Sendable because all members are value types.
public struct ParseResult: Sendable {
  public let file: URL
  public let imports: [String]
  public let targetModuleName: String
}
