import Foundation
import ArgumentParser
import PackageGeneratorCore
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
