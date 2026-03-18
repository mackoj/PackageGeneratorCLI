import Foundation
import SwiftSyntax

class GetImportVisitor: SyntaxRewriter {
  var imports: [String] = []
  
  override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
    guard isSupportedImportAccessModifier(node) else {
      return DeclSyntax(node)
    }
    if let topLevelModule = node.path.first?.name.text.trimmingCharacters(in: .whitespacesAndNewlines),
       topLevelModule.isEmpty == false {
      imports.append(topLevelModule)
    }
    return DeclSyntax(node)
  }
  
  func drain() -> [String] {
    return imports
  }

  private func isSupportedImportAccessModifier(_ node: ImportDeclSyntax) -> Bool {
    let allowed = Set(["public", "internal", "package"])
    let modifiers = node
      .children(viewMode: .all)
      .compactMap { $0.as(DeclModifierListSyntax.self) }
      .flatMap { $0.map(\.name.text) }

    guard modifiers.isEmpty == false else { return true }
    return modifiers.allSatisfy(allowed.contains)
  }
}
