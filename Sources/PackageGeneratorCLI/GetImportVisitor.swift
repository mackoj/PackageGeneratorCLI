import Foundation
import SwiftSyntax

class GetImportVisitor: SyntaxRewriter {
  var imports: [String] = []
  
  override func visit(_ node: AccessPathSyntax) -> Syntax {
    let identifier = node.tokens.compactMap { ts -> String? in
      if case let .identifier(id) = ts.tokenKind, id.isEmpty == false {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
      }
      return nil
    }
    imports.append(contentsOf: identifier)
    return node._syntaxNode
  }
  
  func drain() -> [String] {
    return imports
  }
}
