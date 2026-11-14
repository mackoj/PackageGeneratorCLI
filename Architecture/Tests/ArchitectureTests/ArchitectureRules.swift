import LLMCheck
import Testing

/// The rules, run on the repository. A failure prints the rule, why it exists and how to fix it.
@Suite("Architecture rules")
struct ArchitectureRules {
    static func sources() throws -> Scope { try repository().productionCode.in("/Sources") }
    static func models() throws -> Scope { try sources().in("Sources/PackageGeneratorModels") }
    static func tests() throws -> Scope { try repository().testCode.in("/Tests") }

    @Test func stdoutIsNotWritten() throws {
        expectNone(Detect.stdoutWrites(in: try Self.sources()), rule: .stdoutIsNotWritten)
    }

    @Test func loggersAreCentralised() throws {
        let sources = try Self.sources()
        #expect(!sources.in("Sources/PackageGeneratorCore/Logging").relativePaths.isEmpty)
        expectNone(Detect.strayLoggers(in: sources), rule: .loggersAreCentralised)
    }

    @Test func failuresAreThrown() throws {
        expectNone(Detect.traps(in: try Self.sources()), rule: .failuresAreThrown)
    }

    @Test func modelsDependOnFoundationOnly() throws {
        expectNone(Detect.modelImportsBeyondFoundation(in: try Self.models()), rule: .modelsDependOnFoundationOnly)
    }

    @Test func publicModelsAreCodableAndSendable() throws {
        let models = try Self.models()
        #expect(models.structs.count >= 3)
        expectNone(Detect.publicModelsMissingConformances(in: models), rule: .publicModelsAreCodableAndSendable)
    }

    @Test func uncheckedSendableExplainsItself() throws {
        expectNone(Detect.uncommentedUncheckedSendable(in: try Self.sources()), rule: .uncheckedSendableExplainsItself)
    }

    @Test func parsingGoesThroughTheImportRegion() throws {
        let sources = try Self.sources()
        #expect(sources.calls(named: "parse").contains { $0.node.receiver?.trimmedDescription == "Parser" })
        expectNone(Detect.fullParses(in: sources), rule: .parsingGoesThroughTheImportRegion)
    }

    @Test func testsUseSwiftTesting() throws {
        let tests = try Self.tests()
        #expect(tests.containing("import Testing").relativePaths.count >= 2)
        expectNone(Detect.xcTestImports(in: tests), rule: .testsUseSwiftTesting)
    }

    @Test func testsAreNotDisabled() throws {
        expectNone(Detect.silencedTests(in: try Self.tests()), rule: .testsAreNotDisabled)
    }
}

/// Keeps `docs/architecture-rules.md` in step with the rules. Regenerate with
/// `LLM_CHECK_RECORD=1 swift test --package-path Architecture`.
@Test func rulesDocumentIsUpToDate() throws {
    let catalog = RuleCatalog(allRules)
    #expect(catalog.duplicateIDs.isEmpty)
    try expectFile(
        "docs/architecture-rules.md", in: repository(),
        matches: catalog.markdown(
            title: "Architecture rules",
            introduction: """
                The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with \
                [swift-llm-check](https://github.com/mackoj/swift-llm-check): \
                `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.
                """))
}
