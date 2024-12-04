import Foundation
import SwiftSyntax

class GetImportVisitor: SyntaxRewriter {
  var imports: Set<String> = []
  var importExclusion: Set<String> = []
  
  override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
    if node.baseName.text.lowercased() == "canImport".lowercased() {
      // Build this in a reccursive manner
      //----------------------------------
      // FunctionCallExprSyntax
      // DeclReferenceExprSyntax
      // identifier canimport
      // LabeledExprListSyntax -> Toto
    }
    return ExprSyntax(node)
  }

  override func visit(_ node: ImportPathComponentSyntax) -> ImportPathComponentSyntax {
    imports.insert(node.name.text.trimmingCharacters(in: .whitespacesAndNewlines))
    return node
  }
  
  func drain() -> [String] {
    imports.subtract(importExclusion)
    return Array(imports)
  }
}
