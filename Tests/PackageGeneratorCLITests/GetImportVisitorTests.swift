import Testing
@testable import PackageGeneratorCLI
import SwiftParser
import SwiftSyntax

struct GetImportVisitorTests {
  @Test
  func parsesPlainAndAttributedImports() {
    let imports = extractedImports(
      from:
        """
        import Foundation
        @testable import XCTest
        @_exported import Collections
        """
    )

    #expect(imports == ["Foundation", "XCTest", "Collections"])
  }

  @Test
  func parsesAccessLevelImports() {
    let imports = extractedImports(
      from:
        """
        public import PublicModule
        internal import InternalModule
        package import PackageModule
        private import PrivateModule
        fileprivate import FilePrivateModule
        """
    )

    #expect(imports == ["PublicModule", "InternalModule", "PackageModule"])
  }

  @Test
  func parsesUsableFromInlineAccessLevelImports() {
    let imports = extractedImports(
      from:
        """
        @usableFromInline public import InlinePublicModule
        @usableFromInline internal import InlineInternalModule
        @usableFromInline package import InlinePackageModule
        @usableFromInline fileprivate import FilePrivateModule
        @usableFromInline private import PrivateModule
        """
    )

    #expect(imports == ["InlinePublicModule", "InlineInternalModule", "InlinePackageModule"])
  }

  @Test
  func returnsOnlyTopLevelImportedModule() {
    let imports = extractedImports(
      from:
        """
        import struct Foundation.URL
        """
    )

    #expect(imports == ["Foundation"])
  }

  @Test
  func capturesAccessLevelAndAttributesSemantically() {
    let imports = parsedImportDecls(
      from:
        """
        @usableFromInline public import InlinePublicModule
        public import PublicModule
        internal import InternalModule
        package import PackageModule
        @_exported import ExportedModule
        @testable import XCTest
        """
    )

    let byModule: [String: ImportDeclSyntax] = Dictionary(
      uniqueKeysWithValues: imports.compactMap { importDecl in
        guard let moduleName = moduleName(of: importDecl) else { return nil }
        return (moduleName, importDecl)
      }
    )

    #expect(modifierNames(of: byModule["InlinePublicModule"]) == ["public"])
    #expect(modifierNames(of: byModule["PublicModule"]) == ["public"])
    #expect(modifierNames(of: byModule["InternalModule"]) == ["internal"])
    #expect(modifierNames(of: byModule["PackageModule"]) == ["package"])

    #expect(attributeTexts(of: byModule["InlinePublicModule"]).contains(where: { $0.contains("usableFromInline") }))
    #expect(attributeTexts(of: byModule["ExportedModule"]).contains(where: { $0.contains("_exported") }))
    #expect(attributeTexts(of: byModule["XCTest"]).contains(where: { $0.contains("testable") }))
  }

  private func extractedImports(from source: String) -> [String] {
    let sourceFile = Parser.parse(source: source)
    let visitor = GetImportVisitor(viewMode: .all)
    _ = visitor.visit(sourceFile)
    return visitor.drain()
  }

  private func parsedImportDecls(from source: String) -> [ImportDeclSyntax] {
    let sourceFile = Parser.parse(source: source)
    let collector = ImportDeclCollector(viewMode: .all)
    collector.walk(sourceFile)
    return collector.importDecls
  }

  private func moduleName(of importDecl: ImportDeclSyntax) -> String? {
    let moduleName = importDecl.path.first?.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let moduleName, moduleName.isEmpty == false else { return nil }
    return moduleName
  }

  private func modifierNames(of importDecl: ImportDeclSyntax?) -> [String] {
    guard let importDecl else { return [] }
    return importDecl
      .children(viewMode: .all)
      .compactMap { $0.as(DeclModifierListSyntax.self) }
      .flatMap { $0.map(\.name.text) }
  }

  private func attributeTexts(of importDecl: ImportDeclSyntax?) -> [String] {
    guard let importDecl else { return [] }
    return importDecl
      .children(viewMode: .all)
      .compactMap { $0.as(AttributeListSyntax.self) }
      .flatMap { $0.map(\.trimmedDescription) }
  }
}

private final class ImportDeclCollector: SyntaxVisitor {
  private(set) var importDecls: [ImportDeclSyntax] = []

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    importDecls.append(node)
    return .skipChildren
  }
}
