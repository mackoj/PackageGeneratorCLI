import Foundation
import SwiftSyntax

class GetImportVisitor: SyntaxRewriter {
  var imports: [String] = []
  
  override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
    if let topLevelModule = node.path.first?.name.text.trimmingCharacters(in: .whitespacesAndNewlines),
       topLevelModule.isEmpty == false {
      imports.append(topLevelModule)
    }
    return DeclSyntax(node)
  }
  
  func drain() -> [String] {
    return imports
  }
}
