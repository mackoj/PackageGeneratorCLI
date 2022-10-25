import Foundation
import Files
import ArgumentParser
import SwiftSyntax

@main
struct PackageGeneratorCLI: AsyncParsableCommand {
  
  @Option
  var outputFileURL: FileURL
  
  @Option
  var inputFileURL: FileURL
  
  @Option
  var packageDirectory: FileURL
  
  @Flag
  var verbose: Bool = false
  
  
  func generateParsedPackages() async throws -> [ParsedPackage] {
    let sourceCodeFolder = try Folder(path: packageDirectory.path)
    var parsedPackages: [ParsedPackage] = []
    let fileData = try Data(contentsOf: inputFileURL)
    let lines = try JSONDecoder().decode([String].self, from: fileData)
    for packagePath in lines {
      print("packagePath:", packagePath)
      let folder = try Folder(path: packagePath)
      let (f, ti) = try getImportsFromTarget(folder)
      let parsedPackage = try getTargetOutputFrom(f, ti, sourceCodeFolder)
      parsedPackages.append(parsedPackage)
    }
    return parsedPackages
  }
  
  func hasRessources(_ folder: Folder) -> Folder? {
    return folder.subfolders.recursive.filter {  $0.name == "Resources" }.first
  }
  
  func getTargetOutputFrom(_ packageFolder: Folder, _ imports: [String], _ rootFolder : Folder) throws -> ParsedPackage {
    let hasR = hasRessources(packageFolder)
    return ParsedPackage(
      name: packageFolder.name,
      dependencies: imports,
      path: packageFolder.path(relativeTo: rootFolder),
      fullPath: packageFolder.path,
      resources: hasR != nil ? hasR?.path(relativeTo: packageFolder) : nil
    )
  }
  
  func getImportsFromTarget(_ folder: Folder) throws -> (Folder, [String]) {
    return (folder, try folder.files.recursive.flatMap(getImportsFromFile).unique())
  }
  
  func getImportsFromFile(_ file: File) throws -> [String] {
    let syntaxTree = try SyntaxParser.parse(file.url, diagnosticEngine: .none)
    let visitor = GetImportVisitor()
    _ = visitor.visit(syntaxTree)
    return visitor.drain()
  }
  
  mutating func run() async throws {
    let parsedPackages = try await generateParsedPackages()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(parsedPackages)
    try data.write(to: outputFileURL, options: [.atomic])
  }
}

extension Sequence where Iterator.Element: Hashable {
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}
