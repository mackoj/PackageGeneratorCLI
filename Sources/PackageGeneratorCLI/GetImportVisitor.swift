import Foundation
import SwiftSyntax

class GetImportVisitor: SyntaxRewriter {
  var imports: [String] = []
  
  override func visit(_ node: ImportPathComponentSyntax) -> ImportPathComponentSyntax {
    imports.append(node.name.text.trimmingCharacters(in: .whitespacesAndNewlines))
    return node
  }
  
  func drain() -> [String] {
    return imports
  }
}
