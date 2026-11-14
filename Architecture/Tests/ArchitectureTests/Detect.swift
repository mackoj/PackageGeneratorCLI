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

    /// `Logger(…)` constructed outside `Sources/PackageGeneratorCLI/Logging`.
    static func strayLoggers(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.excluding("Sources/PackageGeneratorCLI/Logging").calls(named: "Logger").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(DeclReferenceExprSyntax.self)
        }
    }

    /// Traps: `fatalError`, `preconditionFailure`, `try!` and `x!`.
    static func traps(in scope: Scope) -> [Match<Syntax>] {
        let calls = scope.calls(named: "fatalError", "preconditionFailure").filter { $0.node.receiver == nil }
        let forcedTries = scope.nodes(of: TryExprSyntax.self) {
            $0.node.questionOrExclamationMark?.tokenKind == .exclamationMark
        }
        let unwraps = scope.nodes(of: ForceUnwrapExprSyntax.self)
        return calls.map(\.erased) + forcedTries.map(\.erased) + unwraps.map(\.erased)
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

    /// `@unchecked Sendable` conformances with no comment on the declaration that makes them.
    static func uncommentedUncheckedSendable(in scope: Scope) -> [Match<AttributeSyntax>] {
        scope.containing("@unchecked").nodes(of: AttributeSyntax.self) { match in
            guard match.node.attributeName.trimmedDescription == "unchecked" else { return false }
            let declaration = sequence(first: Syntax(match.node), next: \.parent).first { $0.is(DeclSyntax.self) }
            return declaration?.attachedComments.isEmpty ?? true
        }
    }

    /// `import XCTest`.
    static func xcTestImports(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports(of: "XCTest")
    }

    /// The `.disabled(…)` trait, and `withKnownIssue { … }` whose first argument is not a string literal.
    static func silencedTests(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        let disabled = scope.calls(named: "disabled").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(MemberAccessExprSyntax.self)
        }
        let knownIssues = scope.calls(named: "withKnownIssue").filter { call in
            guard let first = call.node.arguments.first, first.label == nil else { return true }
            return !first.expression.is(StringLiteralExprSyntax.self)
        }
        return disabled + knownIssues
    }
}
