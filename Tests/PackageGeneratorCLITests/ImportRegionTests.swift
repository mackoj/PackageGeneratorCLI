import SwiftParser
import Testing
@testable import PackageGeneratorCore

/// The scanner parses only the part of a file that can hold imports. On each of these sources it must find exactly
/// what a full parse finds.
struct ImportRegionTests {
  static let sources: [String] = [
    "",
    "struct NoImports { let importer = 1 }",
    "import Foundation\nstruct A {}\nimport SwiftUI\nfunc f() {}",
    "import\n  Foundation\nstruct A {}",
    "import /* why */ Foundation\nlet x = 1",
    "import Foundation // trailing\nlet x = 1",
    "import struct\n  Foundation.URL\nlet x = 1",
    "import Foundation\n  .URL\nlet x = 1",
    "import `Foundation`\nlet x = 1",
    "#if canImport(UIKit)\nimport UIKit\n#else\nimport AppKit\n#endif\nlet x = 1",
    "import Foundation\nlet text = \"import Fake\"\nlet y = 2",
    "import Foundation\n/* import Fake /* nested */ still a comment */\nlet y = 2",
    "import Foundation\n/* unterminated import",
    "import Foundation\n// import Commented\nstruct S { func reimport() {} }",
    "@_exported import A; @testable import B; private import C\nlet x = 1",
    "import Foundation\nlet raw = #\"\"\"\nimport Fake\n\"\"\"#\nlet y = 2",
    "import Foundation\nstruct S {\n  func f() { let importValue = 1 }\n}",
    "let x = 1\nimport Late",
    "import Été\nlet x = 1",
    "import Foundation\nimport",
    "import A\nlet imporimport = 1; let mport = 2; let x = timport",
    "import A\nimport B\nlet t = \"tropmi import\"",
  ]

  @Test(arguments: sources)
  func findsWhatAFullParseFinds(source: String) {
    let visitor = GetImportVisitor(viewMode: .all)
    visitor.walk(Parser.parse(source: source))
    #expect(SwiftFileParser.imports(inSource: source) == visitor.drain())
  }

  @Test func parsesOnlyTheImportLines() {
    var source = "import Foundation\nimport SwiftUI\n\nstruct Body {\n  var value = 1\n}\n"
    let length = source.withUTF8 { ImportRegion.length(of: $0) }
    #expect(length == "import Foundation\nimport SwiftUI".utf8.count)
  }

  @Test func skipsFilesWithoutImports() {
    var source = "struct A { let importer = 1 }"
    #expect(source.withUTF8 { ImportRegion.length(of: $0) } == 0)
  }
}
