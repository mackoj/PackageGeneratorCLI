import Foundation
import SwiftSyntax
import SwiftParser

/// Parses a single Swift source file and extracts its top-level import declarations.
///
/// `SwiftFileParser` is a plain struct with no mutable state.
/// It is `Sendable` and safe to use from any concurrency context.
public struct SwiftFileParser: Sendable {

  public init() {}

  /// Parse a single Swift file and return its extracted (filtered) imports.
  ///
  /// - Parameters:
  ///   - file: Absolute URL to a `.swift` file.
  ///   - targetModuleName: The module that owns this file; self-imports are filtered out.
  /// - Returns: Sorted, deduplicated list of imported module names.
  /// - Throws: `CLIError.ioError` if the file cannot be read; `CancellationError` if the task was cancelled.
  public func parse(file: URL, targetModuleName: String) async throws -> ParseResult {
    try Task.checkCancellation()

    // Only process Swift source files; skip DocC catalogs
    guard file.pathExtension == "swift", !file.path.contains("docc") else {
      return ParseResult(file: file, imports: [], targetModuleName: targetModuleName)
    }

    let source: String
    do {
      source = try String(contentsOf: file, encoding: .utf8)
    } catch {
      throw CLIError.ioError(path: file.path, reason: error.localizedDescription)
    }

    let imports = Self.imports(inSource: source).filter { $0 != targetModuleName }
    return ParseResult(file: file, imports: imports, targetModuleName: targetModuleName)
  }

  /// The modules `source` imports, in order, with duplicates.
  ///
  /// Only the leading part of the file that can hold imports is parsed (see `ImportRegion`): for a typical file,
  /// whose imports are at the top, that is a few lines instead of the whole file.
  package static func imports(inSource source: String) -> [String] {
    var source = source
    return source.withUTF8 { bytes in
      let length = ImportRegion.length(of: bytes)
      guard length > 0 else { return [] }
      let sourceFile = Parser.parse(source: UnsafeBufferPointer(rebasing: bytes[..<length]))
      let visitor = GetImportVisitor(viewMode: .all)
      visitor.walk(sourceFile)
      return visitor.drain()
    }
  }
}
