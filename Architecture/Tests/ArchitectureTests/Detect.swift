import LLMCheck
import SwiftSyntax

/// The detectors, separate from the codebase so `DetectorTests` can run them on snippets.
enum Detect {
    /// `print(x)`, `debugPrint(x)` and `dump(x)` as free functions. `reporter.print(x)` is someone else's method.
    static func stdoutWrites(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.calls(named: "print", "debugPrint", "dump").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(DeclReferenceExprSyntax.self)
        }
    }

    /// `Logger(…)` constructed outside `Sources/PackageGeneratorCore/Logging`.
    static func strayLoggers(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.excluding("Sources/PackageGeneratorCore/Logging").calls(named: "Logger").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(DeclReferenceExprSyntax.self)
        }
    }

    /// Traps: `fatalError`, `preconditionFailure`, `try!` and `x!`.
    static func traps(in scope: Scope) -> [Match<Syntax>] {
        let calls = scope.calls(named: "fatalError", "preconditionFailure").filter { $0.node.receiver == nil }
        return calls.map(\.erased) + scope.forcedTries.map(\.erased) + scope.forceUnwraps.map(\.erased)
    }

    /// Imports in `PackageGeneratorModels` other than Foundation.
    static func modelImportsBeyondFoundation(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports.filter { $0.node.moduleName != "Foundation" }
    }

    /// Public structs and enums that are not declared `Codable` (or `Encodable` and `Decodable`) and `Sendable`.
    static func publicModelsMissingConformances(in scope: Scope) -> [Declaration] {
        (scope.structs + scope.enums).withModifier("public").filter { model in
            let codable = model.inherits(from: "Codable")
                || (model.inherits(from: "Encodable") && model.inherits(from: "Decodable"))
            return !(codable && model.inherits(from: "Sendable"))
        }
    }

    /// `Parser.parse(…)` outside `SwiftFileParser.swift`, and any reference to `SyntaxRewriter`.
    static func fullParses(in scope: Scope) -> [Match<Syntax>] {
        let parses = scope.excluding("SwiftFileParser.swift").calls(named: "parse").filter {
            $0.node.receiver?.trimmedDescription == "Parser"
        }
        return parses.map(\.erased) + scope.references(to: "SyntaxRewriter")
    }

    /// The `.disabled(…)` trait on a `@Test` or `@Suite`, and `withKnownIssue { … }` that gives no reason.
    static func silencedTests(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.disabledTests + scope.unexplainedKnownIssues
    }
}
