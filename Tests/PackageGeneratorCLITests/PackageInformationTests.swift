import Foundation
import PackageGeneratorModels
import Testing

struct PackageInformationTests {
  @Test func decodesObjectsAndLegacyPaths() throws {
    let json = """
      [
        {"target": {"path": "/App/Sources/Checkout", "name": "Checkout"},
         "test": {"path": "/App/Tests/CheckoutTests", "name": "CheckoutTests", "exclude": ["__Snapshots__"]}},
        "/App/Sources/Legacy"
      ]
      """
    let decoded = try JSONDecoder().decode([PackageInformation].self, from: Data(json.utf8))
    #expect(decoded.map(\.target.name) == ["Checkout", "Legacy"])
    #expect(decoded.map(\.target.path) == ["/App/Sources/Checkout", "/App/Sources/Legacy"])
    #expect(decoded[0].test?.exclude == ["__Snapshots__"])
    #expect(decoded[1].test == nil)
    #expect(decoded[1].target.exclude == nil)
  }

  @Test func rejectsOtherValues() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode([PackageInformation].self, from: Data("[42]".utf8))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode([PackageInformation].self, from: Data(#"[{"test": {"path": "a", "name": "b"}}]"#.utf8))
    }
  }
}
