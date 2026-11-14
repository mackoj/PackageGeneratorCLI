import LLMCheck
import Testing

/// Each detector on snippets: it finds what its rule forbids and nothing its rule allows.
@Suite struct DetectorTests {
    func scope(_ source: String, at path: String = "Sources/PackageGeneratorCLI/File.swift") -> Scope {
        Scope(files: [SourceFile(path: path, source: source)])
    }

    @Test func stdoutWritesAreFound() {
        let found = Detect.stdoutWrites(
            in: scope(
                """
                print("parsed")
                debugPrint(imports)
                dump(result)
                """))
        #expect(found.map(\.location.line) == [1, 2, 3])
    }

    @Test func stderrAndMethodsPass() {
        let found = Detect.stdoutWrites(
            in: scope(
                """
                fputs("[package-generator-cli] done\\n", stderr)
                reporter.print(issue)
                let note = "print() in a string is fine"
                """))
        #expect(found.isEmpty)
    }

    @Test func strayLoggersAreFound() {
        let found = Detect.strayLoggers(in: scope(#"let logger = Logger(subsystem: "x", category: "y")"#))
        #expect(found.map(\.location.line) == [1])
    }

    @Test func loggersInLoggingPass() {
        let found = Detect.strayLoggers(
            in: scope(
                #"static let output = Logger(subsystem: subsystem, category: "Output")"#,
                at: "Sources/PackageGeneratorCore/Logging/Loggers.swift"))
        #expect(found.isEmpty)
    }

    @Test func trapsAreFound() {
        let found = Detect.traps(
            in: scope(
                """
                fatalError("unreachable")
                let data = try! Data(contentsOf: url)
                let first = imports.first!
                preconditionFailure("bad state")
                """))
        #expect(found.map(\.location.line).sorted() == [1, 2, 3, 4])
    }

    @Test func safeCodePasses() {
        let found = Detect.traps(
            in: scope(
                """
                let data = try? Data(contentsOf: url)
                let empty = resources?.isEmpty == false
                if !imports.isEmpty, a != b {}
                """))
        #expect(found.isEmpty)
    }

    @Test func modelImportsBeyondFoundationAreFound() {
        let found = Detect.modelImportsBeyondFoundation(
            in: scope("import Foundation\nimport SwiftSyntax", at: "Sources/PackageGeneratorModels/A.swift"))
        #expect(found.map(\.node.moduleName) == ["SwiftSyntax"])
    }

    @Test func missingModelConformancesAreFound() {
        let found = Detect.publicModelsMissingConformances(
            in: scope(
                """
                public struct PackageInformation: Codable, Sendable {
                    public struct PathInfo: Codable {}
                }
                public struct ParsedPackage: Encodable, Decodable, Sendable {}
                public enum Kind: Sendable {}
                struct Internal {}
                """))
        #expect(found.map(\.qualifiedName) == ["PackageInformation.PathInfo", "Kind"])
    }


    @Test func fullParsesAreFound() {
        let found = Detect.fullParses(
            in: scope(
                """
                let tree = Parser.parse(source: text)
                final class Finder: SyntaxRewriter {}
                let imports = SwiftFileParser.imports(inSource: text)
                let value = JSONParser.parse(text)
                """))
        #expect(found.map(\.location.line).sorted() == [1, 2])
    }

    @Test func parsingInSwiftFileParserPasses() {
        let found = Detect.fullParses(
            in: scope(
                "let tree = Parser.parse(source: prefix)",
                at: "Sources/PackageGeneratorCore/Parsing/SwiftFileParser.swift"))
        #expect(found.isEmpty)
    }


    @Test func silencedTestsAreFound() {
        let found = Detect.silencedTests(
            in: scope(
                """
                @Test(.disabled("flaky")) func a() {}
                withKnownIssue { try parse() }
                withKnownIssue("swift-syntax 509 drops attributes (#12)") { try parse() }
                @Test func c() { rule.disabled() }
                """, at: "Tests/T/A.swift"))
        #expect(found.map(\.location.line).sorted() == [1, 2])
    }
}
