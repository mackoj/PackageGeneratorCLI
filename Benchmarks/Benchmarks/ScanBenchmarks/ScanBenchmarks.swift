import Benchmark
import Foundation
import PackageGeneratorCore
import PackageGeneratorModels

/// A synthetic package written to a temporary directory once per process: `targets` targets of `filesPerTarget`
/// Swift files, each with a test target of half as many files, and a `Resources` folder in every other target.
/// Files look like app code: a few imports (some behind `#if`, some access-level or attributed) and a couple of
/// hundred lines of types, functions and closures, which is what the parser spends its time on.
struct SyntheticPackage: Sendable {
  let root: URL
  let input: [PackageInformation]

  static let modules = [
    "Foundation", "SwiftUI", "Combine", "ComposableArchitecture", "Dependencies", "Models", "Networking",
    "DesignSystem", "Analytics", "Persistence", "Localization", "Logging",
  ]

  init(name: String, targets: Int, filesPerTarget: Int) {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("PackageGeneratorBenchmarks-\(ProcessInfo.processInfo.processIdentifier)-\(name)")
    try? FileManager.default.removeItem(at: root)
    var input: [PackageInformation] = []
    for target in 0..<targets {
      let name = "Feature\(target)"
      let sources = root.appendingPathComponent("Sources/\(name)")
      let tests = root.appendingPathComponent("Tests/\(name)Tests")
      Self.write(files: filesPerTarget, module: name, seed: target, to: sources)
      Self.write(files: max(1, filesPerTarget / 2), module: name + "Tests", seed: target + 1, to: tests)
      if target.isMultiple(of: 2) {
        let resources = sources.appendingPathComponent("Resources")
        try! FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try! Data("{}".utf8).write(to: resources.appendingPathComponent("Localizable.xcstrings"))
      }
      let json = """
        {"target": {"path": "\(sources.path)", "name": "\(name)"},
         "test": {"path": "\(tests.path)", "name": "\(name)Tests"}}
        """
      input.append(try! JSONDecoder().decode(PackageInformation.self, from: Data(json.utf8)))
    }
    self.input = input
  }

  static func write(files: Int, module: String, seed: Int, to directory: URL) {
    for file in 0..<files {
      // Spread files over a few sub-folders, like a real target.
      let folder = directory.appendingPathComponent(["", "Views", "Models", "Internal/Helpers"][file % 4])
      try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let url = folder.appendingPathComponent("\(module)File\(file).swift")
      try! Data(source(module: module, index: seed &* 31 &+ file).utf8).write(to: url)
    }
  }

  /// One Swift file of about 220 lines.
  static func source(module: String, index: Int) -> String {
    var lines = ["// \(module)File\(index).swift", "// Copyright © 2026. All rights reserved.", ""]
    for offset in 0..<(3 + index % 4) {
      let imported = modules[(index + offset * 5) % modules.count]
      switch (index + offset) % 6 {
      case 0: lines.append("@testable import \(imported)")
      case 1: lines.append("public import \(imported)")
      case 2: lines.append("import struct \(imported).Value")
      default: lines.append("import \(imported)")
      }
    }
    lines.append("import \(module)")
    lines += ["#if canImport(UIKit)", "import UIKit", "#endif", ""]
    for type in 0..<6 {
      let name = "Type\(index)_\(type)"
      lines += [
        "/// A model for the \(name) screen.",
        "public struct \(name): Hashable, Sendable {",
        "  public var id: Int",
        "  public var title: String",
        "  public var items: [String] = []",
        "  private var cache: [String: Int] = [:]",
        "",
        "  public init(id: Int, title: String) {",
        "    self.id = id",
        "    self.title = title",
        "  }",
        "",
        "  public func summary(limit: Int = 10) -> String {",
        "    let visible = items.prefix(limit).map { $0.uppercased() }.joined(separator: \", \")",
        "    return \"\\(title) (\\(id)): \\(visible)\"",
        "  }",
        "",
        "  public mutating func load(from values: [Int]) async throws {",
        "    for (offset, value) in values.enumerated() where value.isMultiple(of: 2) {",
        "      guard offset < 100 else { break }",
        "      items.append(\"item-\\(value)\")",
        "      cache[\"key\\(offset)\", default: 0] += value",
        "    }",
        "    if items.isEmpty { throw CancellationError() }",
        "  }",
        "",
        "  enum Action: Equatable {",
        "    case tapped(Int)",
        "    case loaded(Result<[String], Never>)",
        "  }",
        "}",
        "",
        "extension \(name) {",
        "  static let preview = \(name)(id: \(type), title: \"Preview \\(\(type))\")",
        "}",
        "",
      ]
    }
    return lines.joined(separator: "\n")
  }
}

/// A large input and output, without touching the disk: what the plugin writes and reads for a big monorepo.
enum JSONFixtures {
  static let targets = 2_000

  static let input: Data = {
    let entries = (0..<targets).map { index in
      index.isMultiple(of: 10)
        ? "\"/Users/dev/Monorepo/Sources/Legacy\(index)\""
        : """
        {"target": {"path": "/Users/dev/Monorepo/Sources/Feature\(index)", "name": "Feature\(index)"},
         "test": {"path": "/Users/dev/Monorepo/Tests/Feature\(index)Tests", "name": "Feature\(index)Tests",
                  "exclude": ["Fixtures", "__Snapshots__"]}}
        """
    }
    return Data("[\(entries.joined(separator: ",\n"))]".utf8)
  }()

  static let output: [ParsedPackage] = (0..<targets).map { index in
    ParsedPackage(
      name: "Feature\(index)", isTest: index.isMultiple(of: 2),
      dependencies: (0..<8).map { SyntheticPackage.modules[(index + $0) % SyntheticPackage.modules.count] }.sorted(),
      path: "Sources/Feature\(index)", fullPath: "/Users/dev/Monorepo/Sources/Feature\(index)",
      resources: index.isMultiple(of: 3) ? "Resources" : nil)
  }
}

let benchmarks: @Sendable () -> Void = {
  Benchmark.defaultConfiguration = .init(
    metrics: [.wallClock, .cpuTotal, .mallocCountTotal, .peakMemoryResident, .retainCount],
    // Exact counts and microseconds, so a change of a few percent shows up in a comparison.
    timeUnits: .microseconds,
    units: [.mallocCountTotal: .count, .retainCount: .count],
    maxDuration: .seconds(3),
    maxIterations: 1_000
  )

  // MARK: Parsing one file at a time

  Benchmark("Parse files, 100 sequentially") { (benchmark: Benchmark, files: [URL]) in
    let parser = SwiftFileParser()
    for file in files {
      blackHole(try await parser.parse(file: file, targetModuleName: "Feature0"))
    }
  } setup: {
    let package = SyntheticPackage(name: "sequential", targets: 1, filesPerTarget: 100)
    return try FileManager.default.subpathsOfDirectory(atPath: package.root.path + "/Sources/Feature0")
      .filter { $0.hasSuffix(".swift") }.sorted()
      .map { package.root.appendingPathComponent("Sources/Feature0/\($0)") }
  }

  // MARK: Scanning (discovery, exclusion, concurrent parsing, resources)

  Benchmark("Scan target, 500 files") { (benchmark: Benchmark, package: SyntheticPackage) in
    let processor = PackageProcessor(packageRoot: package.root)
    blackHole(try await processor.process(package.input))
  } setup: {
    SyntheticPackage(name: "target", targets: 1, filesPerTarget: 500)
  }

  Benchmark("Scan package, 2000 files") { (benchmark: Benchmark, package: SyntheticPackage) in
    let processor = PackageProcessor(packageRoot: package.root)
    blackHole(try await processor.process(package.input))
  } setup: {
    // 40 targets of 34 files, each with a test target of 17: 2,040 files.
    SyntheticPackage(name: "package", targets: 40, filesPerTarget: 34)
  }

  // MARK: JSON in and out

  Benchmark("Decode input JSON, 2000 targets") { benchmark in
    blackHole(try JSONDecoder().decode([PackageInformation].self, from: JSONFixtures.input))
  }

  Benchmark("Encode output JSON, 2000 packages") { benchmark in
    blackHole(try JSONEncoder().encode(JSONFixtures.output))
  }
}
