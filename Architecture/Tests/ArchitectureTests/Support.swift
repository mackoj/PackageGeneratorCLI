import LLMCheck

/// The PackageGeneratorCLI repository, rooted where `.llm-check.yaml` is. Its file list and every parsed file are
/// shared by all suites, which Swift Testing runs in parallel.
func repository() throws -> Codebase { try Codebase() }

extension RuleCategory {
    static let output = RuleCategory(
        "output",
        description: "stdout, stderr and logging. Read before you print, log or report progress."
    )
    static let errors = RuleCategory(
        "errors",
        description: "How the CLI fails. Read before you add a code path that can fail."
    )
    static let models = RuleCategory(
        "models",
        description: "PackageGeneratorModels, the JSON contract with the plugin. Read before you touch a model."
    )
    static let concurrency = RuleCategory(
        "concurrency",
        description: "Sendable and shared state. Read before you add a class or share state across tasks."
    )
    static let performance = RuleCategory(
        "performance",
        description: "The scan path. Read before you parse Swift or walk a syntax tree."
    )
    static let testing = RuleCategory(
        "testing",
        description: "Swift Testing, and no silenced tests. Read before you add, skip or mark a test."
    )
}
