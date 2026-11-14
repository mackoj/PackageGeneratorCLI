import LLMCheck

extension Rule {
    static let stdoutIsNotWritten = Rule(
        id: "stdout-is-not-written",
        title: "The CLI never writes to stdout: no `print`, `debugPrint` or `dump`.",
        category: .output,
        rationale: """
            The PackageGenerator plugin runs the CLI as a subprocess and reads its result from the output file; \
            humans read progress on stderr with `--verbose` (CODING_STANDARDS.md, "Output"). Text on stdout mixes \
            with whatever the host prints and is lost in Xcode's plugin log. Diagnostics belong in os_log, where \
            they can be filtered by subsystem and category.
            """,
        howToFix: """
            Log through a `Loggers` category (`Loggers.importParsing.warning(…)`), and for human progress call \
            `verboseLog(…)` or `fputs(…, stderr)` behind `if verbose`.
            """,
        badExample: #"print("Parsed \(file.lastPathComponent)")"#,
        goodExample: #"Loggers.importParsing.debug("Parsed \(file.lastPathComponent, privacy: .public)")"#
    )

    static let loggersAreCentralised = Rule(
        id: "loggers-are-centralised",
        title: "An `os.Logger` is made only in `Sources/PackageGeneratorCore/Logging`.",
        category: .output,
        rationale: """
            Every log line uses the subsystem `com.mackoj.PackageGeneratorCLI` and one of the categories listed in \
            `Loggers.swift`, so `log stream --predicate 'subsystem == "com.mackoj.PackageGeneratorCLI"'` and \
            Console.app filters see everything (CODING_STANDARDS.md, "Output"). A `Logger` made elsewhere invents a \
            subsystem or category nobody filters on.
            """,
        howToFix: "Use a `Loggers` category, or add one to `Loggers.swift` with a doc comment saying what it covers.",
        badExample: #"let logger = Logger(subsystem: "PackageGenerator", category: "Parser")"#,
        goodExample: #"Loggers.importParsing.debug("…")"#
    )

    static let failuresAreThrown = Rule(
        id: "failures-are-thrown",
        title: "The CLI never traps: no `fatalError`, `preconditionFailure`, `try!` or force unwrap in `Sources`.",
        category: .errors,
        rationale: """
            A trap kills the plugin's subprocess with a signal and no message the user can act on. Failures are \
            `CLIError` values with a readable `errorDescription` that ArgumentParser prints and turns into a \
            non-zero exit (CODING_STANDARDS.md, "Errors"). A single unreadable file is logged and skipped, never \
            fatal for the whole package.
            """,
        howToFix: """
            Throw a `CLIError` case (add one if none fits), or unwrap with `guard let … else { throw … }` or `?.`.
            """,
        badExample: """
            let data = try! Data(contentsOf: inputFileURL)
            resources != nil && resources!.isEmpty == false
            """,
        goodExample: """
            do { data = try Data(contentsOf: inputFileURL) } catch {
                throw CLIError.ioError(path: inputFileURL.path, reason: error.localizedDescription)
            }
            resources?.isEmpty == false
            """
    )

    static let modelsDependOnFoundationOnly = Rule(
        id: "models-depend-on-foundation-only",
        title: "`PackageGeneratorModels` imports Foundation and nothing else.",
        category: .models,
        rationale: """
            `PackageGeneratorModels` is a library product: it is the JSON contract between this CLI and the \
            PackageGenerator plugin, and others may decode the output with it. Importing SwiftSyntax or \
            ArgumentParser there would make every client build them (CODING_STANDARDS.md, "Models").
            """,
        howToFix: "Keep parsing and CLI code in `PackageGeneratorCLI`; models hold data and Codable logic only.",
        badExample: """
            // Sources/PackageGeneratorModels/ParsedPackage.swift
            import SwiftSyntax
            """,
        goodExample: """
            // Sources/PackageGeneratorModels/ParsedPackage.swift
            import Foundation
            """
    )

    static let publicModelsAreCodableAndSendable = Rule(
        id: "public-models-are-codable-and-sendable",
        title: "A public struct or enum in `PackageGeneratorModels` is declared `Codable` and `Sendable`.",
        category: .models,
        rationale: """
            Models cross a process boundary as JSON and cross task boundaries inside the CLI, which processes \
            targets concurrently under Swift 6 (CODING_STANDARDS.md, "Models"). A missing conformance is a source \
            break to add later, since a client cannot add it.
            """,
        howToFix: "Declare both on the type itself, like its neighbours: `public struct ParsedPackage: Codable, Sendable`.",
        badExample: "public struct PathInfo: Codable {",
        goodExample: "public struct PathInfo: Codable, Sendable {"
    )

    static let uncheckedSendableExplainsItself = Rule(
        id: "unchecked-sendable-explains-itself",
        title: "An `@unchecked Sendable` conformance has a comment that proves it safe.",
        category: .concurrency,
        rationale: """
            `@unchecked Sendable` turns off the compiler's data-race check for the type. The comment is the only \
            proof left that the type is safe to share across the task groups that parse files concurrently \
            (CODING_STANDARDS.md, "Concurrency").
            """,
        howToFix: """
            Prefer a value type or an `actor`. If neither fits, put a `//` comment just above the declaration that \
            says what guards the mutable state. A `///` doc comment describes the type to its users and does not \
            count.
            """,
        badExample: "final class MockLogSink: LogSink, @unchecked Sendable {",
        goodExample: """
            // @unchecked Sendable: every access to `_entries` holds `lock`.
            final class MockLogSink: LogSink, @unchecked Sendable {
            """
    )

    static let testsUseSwiftTesting = Rule(
        id: "tests-use-swift-testing",
        title: "Tests use Swift Testing, never XCTest.",
        category: .testing,
        rationale: """
            The suite is Swift Testing only (CODING_STANDARDS.md, "Tests"): `@Test`, `#expect` and `#require` give \
            one failure message style, parameterised tests and parallel runs.
            """,
        howToFix: "Write `@Test` functions with `#expect` and `#require`, and `import Testing`.",
        badExample: """
            import XCTest
            final class GetImportVisitorTests: XCTestCase { func testPlain() { XCTAssertEqual(…) } }
            """,
        goodExample: """
            import Testing
            struct GetImportVisitorTests { @Test func parsesPlainImports() { #expect(…) } }
            """
    )

    static let testsAreNotDisabled = Rule(
        id: "tests-are-not-disabled",
        title: "No test or suite is `.disabled`, and `withKnownIssue` says why.",
        category: .testing,
        rationale: """
            A disabled test still reads as coverage while checking nothing, and a known issue without a reason \
            hides a failing expectation nobody will come back to (CODING_STANDARDS.md, "Tests").
            """,
        howToFix: """
            Fix the code or the test. If the bug must wait, wrap the failing part in \
            `withKnownIssue("<what and where it is tracked>")`.
            """,
        badExample: """
            @Test(.disabled("flaky")) func parsesConditionalImports() {
            withKnownIssue { … }
            """,
        goodExample: """
            @Test func parsesConditionalImports() {
            withKnownIssue("#if imports are not evaluated (mackoj/PackageGeneratorCLI#N)") { … }
            """
    )
}

extension Rule {
    static let parsingGoesThroughTheImportRegion = Rule(
        id: "parsing-goes-through-the-import-region",
        title: "Only `SwiftFileParser` calls `Parser.parse`, and nothing in `Sources` subclasses `SyntaxRewriter`.",
        category: .performance,
        rationale: """
            Parsing whole files was over 90% of a scan's time and allocations. `SwiftFileParser.imports(inSource:)` \
            parses only the leading part of a file that can hold imports (`ImportRegion`), which made scans about \
            25 times faster (docs/performance.md, "What has paid off"). A second `Parser.parse` call site, or a \
            `SyntaxRewriter` that walks and rebuilds every node, brings that cost back.
            """,
        howToFix: """
            Call `SwiftFileParser.imports(inSource:)` or `SwiftFileParser().parse(file:targetModuleName:)`. To read \
            the tree, subclass `SyntaxVisitor` and return `.skipChildren` from nodes whose inside you do not need.
            """,
        badExample: """
            let tree = Parser.parse(source: try String(contentsOf: file, encoding: .utf8))
            final class ImportFinder: SyntaxRewriter { … }
            """,
        goodExample: """
            let imports = SwiftFileParser.imports(inSource: source)
            final class GetImportVisitor: SyntaxVisitor { … }
            """
    )
}

/// Every rule, in the order `docs/architecture-rules.md` lists them.
let allRules: [Rule] = [
    .stdoutIsNotWritten, .loggersAreCentralised, .failuresAreThrown, .modelsDependOnFoundationOnly,
    .publicModelsAreCodableAndSendable, .uncheckedSendableExplainsItself, .testsUseSwiftTesting,
    .parsingGoesThroughTheImportRegion, .testsAreNotDisabled,
]
