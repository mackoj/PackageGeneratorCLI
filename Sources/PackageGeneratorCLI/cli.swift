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

    var lines: [String] = []
    do {
      lines = try JSONDecoder().decode([String].self, from: fileData)
    } catch {
      fatalError("Failed to JSONDecoder Data from \(inputFileURL.path) in [String].self")
    }
    
    for packagePath in lines {
      if FileManager.default.fileExists(atPath: packagePath) == false {
        print("❌ \(packagePath) not found")
        continue
      }

      var folder: Folder
      do {
        folder = try Folder(path: packagePath)
      } catch {
        fatalError("Failed to create Folder with \(packagePath)")
      }

      let (f, ti) = getImportsFromTarget(folder)
      let parsedPackage = getTargetOutputFrom(f, ti, sourceCodeFolder)
      parsedPackages.append(parsedPackage)
    }
    return parsedPackages
  }
  
  func hasRessources(_ folder: Folder) -> Folder? {
    return folder.subfolders.recursive.filter {  $0.name == "Resources" }.first
  }
  
  func getTargetOutputFrom(_ packageFolder: Folder, _ imports: [String], _ rootFolder : Folder) -> ParsedPackage {
    let hasR = hasRessources(packageFolder)
    return ParsedPackage(
      name: packageFolder.name,
      dependencies: imports,
      path: packageFolder.path(relativeTo: rootFolder),
      fullPath: packageFolder.path,
      resources: hasR != nil ? hasR?.path(relativeTo: packageFolder) : nil
    )
  }
  
  func getImportsFromTarget(_ folder: Folder) -> (Folder, [String]) {
    return (folder, folder.files.recursive.flatMap(getImportsFromFile).unique())
  }
  
  func getImportsFromFile(_ file: File) -> [String] {
    do {
      let syntaxTree = try SyntaxParser.parse(file.url, diagnosticEngine: .none)
      let visitor = GetImportVisitor()
      _ = visitor.visit(syntaxTree)
      return visitor.drain()
    } catch {
      print("💥 Failed to extract imports from \(file)")
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
    print("package-generator-cli has finished")
  }
}

extension Sequence where Iterator.Element: Hashable {
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}
