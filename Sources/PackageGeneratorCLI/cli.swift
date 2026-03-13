import Foundation
import Files
import ArgumentParser
import SwiftSyntax
import SwiftParser
import PackageGeneratorModels

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
  
  
  func generateParsedPackages() async -> [ParsedPackage] {
    
    
    var sourceCodeFolder: Folder
    do {
      sourceCodeFolder = try Folder(path: packageDirectory.path)
    } catch {
      fatalError("Failed to create Folder with \(packageDirectory.path)")
    }
    
    var parsedPackages: [ParsedPackage] = []
    var fileData: Data
    do {
      fileData = try Data(contentsOf: inputFileURL)
    } catch {
      fatalError("Failed to create Data from \(inputFileURL.path)")
    }

    var lines: [PackageInformation] = []
    do {
      lines = try JSONDecoder().decode([PackageInformation].self, from: fileData)
    } catch {
      fatalError("Failed to JSONDecoder Data from \(inputFileURL.path) in [PackageInformation].self")
    }
    
    for packagePath in lines {
      if FileManager.default.fileExists(atPath: packagePath.target.path) == false {
        print("❌ \(packagePath) not found")
        continue
      }

      do {
        let folder = try Folder(path: packagePath.target.path)
        let targetModuleName = moduleName(for: packagePath, isTest: false)
        logInfo("Processing target module \"\(targetModuleName)\" at \(folder.path)")
        let (targetFolder, targetImport) = getImportsFromTarget(
          folder,
          targetModuleName: targetModuleName,
          packageRoot: sourceCodeFolder,
          excludes: packagePath.target.exclude
        )
        let parsedPackage = getTargetOutputFrom(packagePath, false, targetFolder, targetImport, sourceCodeFolder)
        parsedPackages.append(parsedPackage)
        
        if let testPath = packagePath.test?.path {
          let testPathFolder = try Folder(path: testPath)
          let testModuleName = moduleName(for: packagePath, isTest: true)
          logInfo("Processing test module \"\(testModuleName)\" at \(testPathFolder.path)")
          let (testFolder, testImport) = getImportsFromTarget(
            testPathFolder,
            targetModuleName: testModuleName,
            packageRoot: sourceCodeFolder,
            excludes: packagePath.test?.exclude
          )
          parsedPackages.append(getTargetOutputFrom(packagePath, true, testFolder, testImport, sourceCodeFolder))
        }
        
      } catch {
        fatalError("Failed to create Folder with \(packagePath)")
      }
    }
    return parsedPackages
  }
  
  func hasRessources(_ folder: Folder) -> Folder? {
    return folder.subfolders.recursive.filter {  $0.name == "Resources" }.first
  }
  
  func getTargetOutputFrom(_ packageInfo: PackageInformation, _ isTest: Bool, _ packageFolder: Folder, _ dependencies: [String], _ rootFolder : Folder) -> ParsedPackage {
    let hasR = hasRessources(packageFolder)
    return ParsedPackage(
      name: packageInfo.target.name,
      isTest: isTest,
      dependencies: dependencies,
      path: packageFolder.path(relativeTo: rootFolder),
      fullPath: packageFolder.path,
      resources: hasR != nil ? hasR?.path(relativeTo: packageFolder) : nil
    )
  }
  
  func getImportsFromTarget(
    _ folder: Folder,
    targetModuleName: String,
    packageRoot: Folder,
    excludes: [String]?
  ) -> (Folder, [String]) {
    let files = folder.files.recursive.filter {
      !isFileExcluded($0, baseFolder: folder, packageRoot: packageRoot, excludes: excludes)
    }
    let imports = files.flatMap { getImportsFromFile($0, targetModuleName: targetModuleName) }.unique()
    return (folder, imports)
  }

  private func isFileExcluded(
    _ file: File,
    baseFolder: Folder,
    packageRoot: Folder,
    excludes: [String]?
  ) -> Bool {
    guard let excludes = excludes, excludes.isEmpty == false else { return false }
    let absolutePath = file.url.standardized.path
    let relativeToTarget = file.path(relativeTo: baseFolder)
    let relativeToPackage = file.path(relativeTo: packageRoot)
    let strippedPackageRelative = strippedRootPrefix(relativeToPackage)

    for raw in excludes {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.isEmpty == false else { continue }
      if trimmed.hasPrefix("/") {
        let normalized = URL(fileURLWithPath: trimmed).standardized.path
        if absolutePath == normalized || absolutePath.hasPrefix(normalized + "/") {
          return true
        }
        continue
      }
      let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
      if matchesRelative(path: relativeToTarget, candidate: cleaned) {
        return true
      }
      if matchesRelative(path: relativeToPackage, candidate: cleaned) {
        return true
      }
      if matchesRelative(path: strippedPackageRelative, candidate: cleaned) {
        return true
      }
    }
    return false
  }

  private func matchesRelative(path: String, candidate: String) -> Bool {
    guard candidate.isEmpty == false else { return false }
    return path == candidate || path.hasPrefix(candidate + "/")
  }

  private func strippedRootPrefix(_ path: String) -> String {
    if path.hasPrefix("Sources/") {
      return String(path.dropFirst("Sources/".count))
    }
    if path.hasPrefix("Tests/") {
      return String(path.dropFirst("Tests/".count))
    }
    return path
  }
  
  func getImportsFromFile(_ file: File, targetModuleName: String) -> [String] {
    guard file.extension == "swift" else { return [] }
    guard !file.url.path.contains("docc") else { return [] }

    do {
      let source = try String(contentsOf: file.url, encoding: .utf8)
      let sourceFile = Parser.parse(source: source)
      let visitor = GetImportVisitor(viewMode: SyntaxTreeViewMode.all)
      _ = visitor.visit(sourceFile)
      let imports = visitor.drain()
      let filteredImports = imports.filter { $0 != targetModuleName }
      if imports.count != filteredImports.count {
        logWarning("Filtered self-import \"\(targetModuleName)\" from \(file.path)")
      }
      return filteredImports
    } catch {
      logWarning("Failed to extract imports from \(file.path): \(error.localizedDescription)")
    }
    return []
  }
  
  mutating func run() async throws {
    let parsedPackages = await generateParsedPackages()
    let encoder = JSONEncoder()
    if verbose { encoder.outputFormatting = .prettyPrinted }

    var data: Data
    do {
      data = try encoder.encode(parsedPackages)
    } catch {
      fatalError("Failed to encode parsedPackages")
    }

    do {
      try data.write(to: outputFileURL, options: [.atomic])
    } catch {
      fatalError("Failed to write parsedPackages in \(outputFileURL.path)")
    }
    logInfo("package-generator-cli has finished")
  }
}

extension PackageGeneratorCLI {
  private func moduleName(for packageInfo: PackageInformation, isTest: Bool) -> String {
    return "\(packageInfo.target.name)\(isTest ? "Tests" : "")"
  }

  private func logInfo(_ message: String) {
    print("[package-generator-cli] \(message)")
  }

  private func logWarning(_ message: String) {
    print("[package-generator-cli WARNING] \(message)")
  }

}

extension Sequence where Iterator.Element: Hashable {
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}
