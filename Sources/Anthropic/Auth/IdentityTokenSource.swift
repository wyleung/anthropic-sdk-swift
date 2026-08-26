import Foundation

/// Supplies the identity token (JWT assertion) presented to the WIF token endpoint. Ported from
/// the reference SDKs' 4 sourcing variants: a config-file path, an `ANTHROPIC_IDENTITY_TOKEN_FILE`
/// env-var path (both `FileIdentityTokenSource`), the literal `ANTHROPIC_IDENTITY_TOKEN` env value
/// (`EnvIdentityTokenSource`), or a caller-supplied closure (the escape hatch for e.g. cloud
/// metadata-service fetchers -- neither reference SDK ships a built-in IMDS fetcher).
public protocol IdentityTokenSource: Sendable {
    func token() async throws -> String
}

/// Re-reads the file on every call -- no caching -- matching both reference SDKs, since an external
/// process (e.g. a sidecar rotating a projected service-account token) may replace it at any time.
public struct FileIdentityTokenSource: IdentityTokenSource {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    public func token() async throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw AnthropicError.responseValidation(
                message: "Could not read identity token file at \(path): \(error.localizedDescription)", body: nil
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw AnthropicError.responseValidation(
                message: "Identity token file at \(path) is not valid UTF-8.", body: nil
            )
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AnthropicError.responseValidation(message: "Identity token file at \(path) is empty.", body: nil)
        }
        return trimmed
    }
}

/// Reads a live environment variable on every call (never captured at construction), matching the
/// reference SDKs' closure-based literal-env-var sourcing -- only reachable via the pure-env-var
/// chain path (`ANTHROPIC_IDENTITY_TOKEN`), never via a config-file profile.
struct EnvIdentityTokenSource: IdentityTokenSource {
    let variableName: String

    func token() async throws -> String {
        guard let value = ProcessInfo.processInfo.environment[variableName], !value.isEmpty else {
            throw AnthropicError.responseValidation(
                message: "Environment variable \(variableName) is not set.", body: nil
            )
        }
        return value
    }
}
