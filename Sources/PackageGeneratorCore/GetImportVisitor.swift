import Foundation
import SwiftSyntax

/// Collects the top-level module of every import declaration whose access level is public, internal or package
/// (or unspecified).
///
/// A `SyntaxVisitor`, not a `SyntaxRewriter`: it only reads the tree, and it skips the inside of each import.
final class GetImportVisitor: SyntaxVisitor {
  private(set) var imports: [String] = []

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    if isSupportedImportAccessModifier(node),
      let topLevelModule = node.path.first?.name.text.trimmingCharacters(in: .whitespacesAndNewlines),
      topLevelModule.isEmpty == false
    {
      imports.append(topLevelModule)
    }
    return .skipChildren
  }

  func drain() -> [String] {
    return imports
  }

  private func isSupportedImportAccessModifier(_ node: ImportDeclSyntax) -> Bool {
    node.modifiers.allSatisfy { modifier in
      switch modifier.name.text {
      case "public", "internal", "package": true
      default: false
      }
    }
  }
}
