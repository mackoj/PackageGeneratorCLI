import Foundation
import ArgumentParser
import SwiftSyntax
import SwiftParser
import PackageGeneratorModels
import OSLog

// MARK: - Entry Point

@main
struct PackageGeneratorCLI: AsyncParsableCommand {

  @Option var outputFileURL: FileURL
  @Option var inputFileURL: FileURL
  @Option var packageDirectory: FileURL

  /// When set, prints human-readable progress to stderr.
  /// stdout always carries only the JSON output.
  @Flag var verbose: Bool = false

  mutating func run() async throws {
    let clock = ContinuousClock()
    let startTime = clock.now

    verboseLog("package-generator-cli started")
    Loggers.lifecycle.info("package-generator-cli started")

    // Load input
    let lines = try loadInput()
    Loggers.configuration.info(
      "Loaded \(lines.count, privacy: .public) targets from input"
    )
    verboseLog("Processing \(lines.count) targets")

    // Build a Sendable processor (avoids capturing `self` in task groups)
    let processor = PackageProcessor(
      packageRoot: packageDirectory,
      verbose: verbose
    )

    // Process all targets concurrently
    let parsedPackages = try await processor.process(lines)

    // Write JSON to output file (stdout-safe: only data, no text)
    let encoder = JSONEncoder()
    if verbose { encoder.outputFormatting = .prettyPrinted }

    let data: Data
    do {
      data = try encoder.encode(parsedPackages)
    } catch {
      throw CLIError.writeFailure(path: outputFileURL.path, reason: error.localizedDescription)
    }

    do {
      try data.write(to: outputFileURL, options: [.atomic])
    } catch {
      throw CLIError.writeFailure(path: outputFileURL.path, reason: error.localizedDescription)
    }

    let outputName = outputFileURL.lastPathComponent
    Loggers.output.info(
      "Wrote \(parsedPackages.count, privacy: .public) packages to \(outputName, privacy: .public)"
    )

    let elapsed = clock.now - startTime
    let count = parsedPackages.count
    Loggers.lifecycle.info(
      "package-generator-cli finished: \(count, privacy: .public) targets, elapsed=\(elapsed, privacy: .public)"
    )
    verboseLog("Finished: \(count) packages written, elapsed: \(elapsed)")
  }

  // MARK: - Input loading

  private func loadInput() throws -> [PackageInformation] {
    Loggers.configuration.debug("Loading input from \(inputFileURL.path, privacy: .private)")

    guard FileManager.default.fileExists(atPath: inputFileURL.path) else {
      throw CLIError.fileNotFound(path: inputFileURL.path)
    }

    let data: Data
    do {
      data = try Data(contentsOf: inputFileURL)
    } catch {
      throw CLIError.ioError(path: inputFileURL.path, reason: error.localizedDescription)
    }

    do {
      return try JSONDecoder().decode([PackageInformation].self, from: data)
    } catch {
      throw CLIError.invalidJSON(file: inputFileURL.path, reason: error.localizedDescription)
    }
  }

  // MARK: - Verbose stderr helper

  /// Prints a progress message to stderr (never stdout).
  /// Calling this while `verbose == false` is a no-op.
  private func verboseLog(_ message: String) {
    guard verbose else { return }
    fputs("[package-generator-cli] \(message)\n", stderr)
  }
}

// MARK: - PackageProcessor

/// Encapsulates all concurrent target processing logic.
/// Defined as a separate Sendable struct so it can be safely captured
/// in `withThrowingTaskGroup` closures under Swift 6 strict concurrency.
struct PackageProcessor: Sendable {
  let packageRoot: URL
  let verbose: Bool

  // MARK: Top-level

  func process(_ lines: [PackageInformation]) async throws -> [ParsedPackage] {
    guard !lines.isEmpty else { return [] }

    let maxConcurrent = min(
      ProcessInfo.processInfo.activeProcessorCount * 2,
      lines.count
    )
    Loggers.concurrency.debug(
      "Processing \(lines.count, privacy: .public) targets, maxConcurrent=\(maxConcurrent, privacy: .public)"
    )

    return try await withThrowingTaskGroup(of: [ParsedPackage].self) { group in
      var iterator = lines.makeIterator()

      // Seed initial batch
      for _ in 0..<maxConcurrent {
        guard let pkg = iterator.next() else { break }
        let name = pkg.target.name
        group.addTask {
          try await self.processTarget(pkg)
        }
        Loggers.concurrency.debug("Queued target: \(name, privacy: .public)")
      }

      var all: [ParsedPackage] = []
      do {
        for try await results in group {
          all.append(contentsOf: results)
          if let pkg = iterator.next() {
            let name = pkg.target.name
            group.addTask {
              try await self.processTarget(pkg)
            }
            Loggers.concurrency.debug("Queued target: \(name, privacy: .public)")
          }
        }
      } catch is CancellationError {
        throw CancellationError()
      }

      return all
    }
  }

  // MARK: Per-target

  private func processTarget(_ packageInfo: PackageInformation) async throws -> [ParsedPackage] {
    try Task.checkCancellation()

    let targetPath = packageInfo.target.path
    guard FileManager.default.fileExists(atPath: targetPath) else {
      Loggers.fileDiscovery.warning(
        "Target directory not found, skipping: \(targetPath, privacy: .private)"
      )
      if verbose { fputs("[package-generator-cli] ❌ \(targetPath) not found\n", stderr) }
      return []
    }

    let targetURL = URL(fileURLWithPath: targetPath)
    let targetModuleName = moduleName(for: packageInfo, isTest: false)

    Loggers.fileDiscovery.info(
      "Processing target \(targetModuleName, privacy: .public)"
    )
    if verbose { fputs("[package-generator-cli] Processing target \"\(targetModuleName)\"\n", stderr) }

    let targetImports = try await parseFilesParallel(
      in: targetURL,
      targetModuleName: targetModuleName,
      excludes: packageInfo.target.exclude
    )

    let resourcesPath = findResourcesFolder(in: targetURL)
      .map { $0.pathRelative(to: targetURL) }

    var results: [ParsedPackage] = [
      ParsedPackage(
        name: packageInfo.target.name,
        isTest: false,
        dependencies: targetImports,
        path: targetURL.pathRelative(to: packageRoot),
        fullPath: targetURL.path,
        resources: resourcesPath
      )
    ]

    // Test target (optional)
    if let testInfo = packageInfo.test {
      guard FileManager.default.fileExists(atPath: testInfo.path) else {
        Loggers.fileDiscovery.warning(
          "Test directory not found, skipping: \(testInfo.path, privacy: .private)"
        )
        return results
      }

      let testURL = URL(fileURLWithPath: testInfo.path)
      let testModuleName = moduleName(for: packageInfo, isTest: true)

      Loggers.fileDiscovery.info(
        "Processing test module \(testModuleName, privacy: .public)"
      )
      if verbose { fputs("[package-generator-cli] Processing test module \"\(testModuleName)\"\n", stderr) }

      let testImports = try await parseFilesParallel(
        in: testURL,
        targetModuleName: testModuleName,
        excludes: testInfo.exclude
      )

      results.append(ParsedPackage(
        name: packageInfo.target.name,
        isTest: true,
        dependencies: testImports,
        path: testURL.pathRelative(to: packageRoot),
        fullPath: testURL.path,
        resources: nil
      ))
    }

    return results
  }

  // MARK: Parallel file parsing

  private func parseFilesParallel(
    in directory: URL,
    targetModuleName: String,
    excludes: [String]?
  ) async throws -> [String] {
    let allFiles = discoverFiles(in: directory)
    let filteredFiles = allFiles.filter {
      !isFileExcluded($0, baseFolder: directory, excludes: excludes)
    }

    Loggers.fileDiscovery.debug(
      "Found \(filteredFiles.count, privacy: .public) Swift files in \(directory.lastPathComponent, privacy: .public)"
    )

    guard !filteredFiles.isEmpty else { return [] }

    let parser = SwiftFileParser()
    let maxConcurrent = min(
      ProcessInfo.processInfo.activeProcessorCount * 2,
      filteredFiles.count
    )

    Loggers.concurrency.debug(
      "Parsing \(filteredFiles.count, privacy: .public) files, concurrency=\(maxConcurrent, privacy: .public)"
    )

    var allImports = Set<String>()

    try await withThrowingTaskGroup(
      of: (URL, Result<[String], any Error>).self
    ) { group in
      var iterator = filteredFiles.makeIterator()

      // Seed initial batch
      for _ in 0..<maxConcurrent {
        guard let file = iterator.next() else { break }
        let capturedFile = file
        let capturedModuleName = targetModuleName
        group.addTask {
          do {
            let result = try await parser.parse(file: capturedFile, targetModuleName: capturedModuleName)
            return (capturedFile, .success(result.imports))
          } catch is CancellationError {
            return (capturedFile, .failure(CancellationError()))
          } catch {
            return (capturedFile, .failure(error))
          }
        }
      }

      // Sliding window: start the next file as each one finishes
      for try await (file, result) in group {
        switch result {
        case .success(let imports):
          allImports.formUnion(imports)
          Loggers.importParsing.debug(
            "Parsed \(file.lastPathComponent, privacy: .public): \(imports.count, privacy: .public) imports"
          )

        case .failure(let error) where error is CancellationError:
          throw CancellationError()

        case .failure(let error):
          Loggers.importParsing.warning(
            "Parse failed for \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
          )
        }

        if let next = iterator.next() {
          let capturedNext = next
          let capturedModuleName = targetModuleName
          group.addTask {
            do {
              let result = try await parser.parse(file: capturedNext, targetModuleName: capturedModuleName)
              return (capturedNext, .success(result.imports))
            } catch is CancellationError {
              return (capturedNext, .failure(CancellationError()))
            } catch {
              return (capturedNext, .failure(error))
            }
          }
        }
      }
    }

    // Sort for deterministic, diff-friendly output
    return allImports.sorted()
  }

  // MARK: File discovery

  private func discoverFiles(in directory: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }
    return enumerator.compactMap { $0 as? URL }
  }

  private func findResourcesFolder(in directory: URL) -> URL? {
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else { return nil }

    for case let url as URL in enumerator {
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
         isDir.boolValue,
         url.lastPathComponent == "Resources" {
        return url
      }
    }
    return nil
  }

  // MARK: Exclusion logic

  private func isFileExcluded(
    _ file: URL,
    baseFolder: URL,
    excludes: [String]?
  ) -> Bool {
    guard let excludes, !excludes.isEmpty else { return false }
    let absolutePath = file.standardized.path
    let relativeToTarget = file.pathRelative(to: baseFolder)
    let relativeToPackage = file.pathRelative(to: packageRoot)
    let strippedPackageRelative = strippedRootPrefix(relativeToPackage)

    for raw in excludes {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      if trimmed.hasPrefix("/") {
        let normalized = URL(fileURLWithPath: trimmed).standardized.path
        if absolutePath == normalized || absolutePath.hasPrefix(normalized + "/") {
          return true
        }
        continue
      }

      let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
      if matchesRelative(path: relativeToTarget, candidate: cleaned) { return true }
      if matchesRelative(path: relativeToPackage, candidate: cleaned) { return true }
      if matchesRelative(path: strippedPackageRelative, candidate: cleaned) { return true }
    }
    return false
  }

  private func matchesRelative(path: String, candidate: String) -> Bool {
    guard !candidate.isEmpty else { return false }
    return path == candidate || path.hasPrefix(candidate + "/")
  }

  private func strippedRootPrefix(_ path: String) -> String {
    if path.hasPrefix("Sources/") { return String(path.dropFirst("Sources/".count)) }
    if path.hasPrefix("Tests/")   { return String(path.dropFirst("Tests/".count)) }
    return path
  }

  // MARK: Helpers

  private func moduleName(for packageInfo: PackageInformation, isTest: Bool) -> String {
    "\(packageInfo.target.name)\(isTest ? "Tests" : "")"
  }
}

// MARK: - URL + Relative Path

extension URL {
  /// Returns the path of `self` relative to `base`.
  /// Falls back to the absolute path if `self` is not under `base`.
  func pathRelative(to base: URL) -> String {
    let basePath = base.standardized.path
    let selfPath = standardized.path
    let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
    guard selfPath.hasPrefix(prefix) else { return selfPath }
    return String(selfPath.dropFirst(prefix.count))
  }
}
