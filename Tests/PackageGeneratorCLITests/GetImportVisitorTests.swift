import XCTest
@testable import PackageGeneratorCLI
import SwiftParser
import SwiftSyntax

final class GetImportVisitorTests: XCTestCase {
  func testParsesPlainAndAttributedImports() {
    let imports = extractedImports(
      from:
        """
        import Foundation
        @testable import XCTest
        @_exported import Collections
        """
    )

    XCTAssertEqual(imports, ["Foundation", "XCTest", "Collections"])
  }

  func testParsesAccessLevelImports() {
    let imports = extractedImports(
      from:
        """
        public import PublicModule
        internal import InternalModule
        package import PackageModule
        """
    )

    XCTAssertEqual(imports, ["PublicModule", "InternalModule", "PackageModule"])
  }

  func testParsesUsableFromInlineAccessLevelImports() {
    let imports = extractedImports(
      from:
        """
        @usableFromInline public import InlinePublicModule
        @usableFromInline internal import InlineInternalModule
        @usableFromInline package import InlinePackageModule
        """
    )

    XCTAssertEqual(
      imports,
      ["InlinePublicModule", "InlineInternalModule", "InlinePackageModule"]
    )
  }

  func testReturnsOnlyTopLevelImportedModule() {
    let imports = extractedImports(
      from:
        """
        import struct Foundation.URL
        """
    )

    XCTAssertEqual(imports, ["Foundation"])
  }

  private func extractedImports(from source: String) -> [String] {
    let sourceFile = Parser.parse(source: source)
    let visitor = GetImportVisitor(viewMode: SyntaxTreeViewMode.all)
    _ = visitor.visit(sourceFile)
    return visitor.drain()
  }
}
