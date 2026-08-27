import Anthropic
import CryptoKit
import Foundation

/// Client-independent Standard Webhooks (https://www.standardwebhooks.com) verification, mirroring
/// the reference SDKs' `Webhook.verify`/`webhook_key` flow. No `AnthropicClient` is required --
/// `unwrap` only needs the raw request payload, its headers, and the signing secret -- so this is a
/// plain namespace rather than a resource. `client.beta.webhooks.unwrap` (see `BetaWebhooks.swift`)
/// is a thin, zero-storage forwarder kept only for call-site parity with the reference SDKs.
///
/// The algorithm below was confirmed directly against the real `standardwebhooks` PyPI package
/// source (not just its public docs), since several details are unconditional/exact where a
/// pure-spec reading could plausibly get them wrong: the `whsec_` secret is *always* padded with
/// `"=="` before base64 decoding (not just when padding looks missing), the replay window is
/// exactly +/-5 minutes compared as `Date`s (not epoch-second integer arithmetic), and header
/// lookup is case-insensitive.
public enum AnthropicWebhooks {
    private static let secretPrefix = "whsec_"
    private static let tolerance: TimeInterval = 5 * 60

    /// Verifies the HMAC-SHA256 signature on a webhook request and decodes its body.
    ///
    /// - Parameters:
    ///   - payload: The raw, unparsed request body exactly as received -- the signature covers
    ///     these exact bytes, so re-serializing the JSON before calling this will break
    ///     verification on any payload where key order or whitespace isn't byte-identical.
    ///   - headers: The request headers. Lookup of `webhook-id`/`webhook-signature`/
    ///     `webhook-timestamp` is case-insensitive.
    ///   - key: The webhook signing secret, in either the `whsec_`-prefixed or bare base64 form.
    ///   - clock: Supplies the current time for the +/-5-minute replay window; defaults to the
    ///     system clock. Overridable so tests can verify fixed, non-live timestamps deterministically.
    /// - Throws: `AnthropicError.webhookValidation` if headers are missing, the timestamp is
    ///   malformed or outside the tolerance window, or no candidate signature matches.
    public static func unwrap(
        payload: String,
        headers: [String: String],
        key: String,
        clock: () -> Date = { Date() }
    ) throws -> UnwrapWebhookEvent {
        let normalizedHeaders = headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        guard let msgId = normalizedHeaders["webhook-id"],
            let msgSignature = normalizedHeaders["webhook-signature"],
            let msgTimestamp = normalizedHeaders["webhook-timestamp"]
        else {
            throw AnthropicError.webhookValidation(message: "Missing required headers")
        }

        guard let timestampSeconds = Double(msgTimestamp) else {
            throw AnthropicError.webhookValidation(message: "Invalid Signature Headers")
        }
        let timestampDate = Date(timeIntervalSince1970: timestampSeconds)
        let now = clock()
        if timestampDate < now.addingTimeInterval(-tolerance) {
            throw AnthropicError.webhookValidation(message: "Message timestamp too old")
        }
        if timestampDate > now.addingTimeInterval(tolerance) {
            throw AnthropicError.webhookValidation(message: "Message timestamp too new")
        }

        let secretData = try decodeSecret(key)
        let symmetricKey = SymmetricKey(data: secretData)
        let flooredTimestamp = String(Int(timestampSeconds.rounded(.down)))
        let signedContent = Data("\(msgId).\(flooredTimestamp).\(payload)".utf8)

        var matched = false
        for candidate in msgSignature.split(separator: " ") {
            let parts = candidate.split(separator: ",", maxSplits: 1)
            guard parts.count == 2, parts[0] == "v1", let candidateMac = Data(base64Encoded: String(parts[1]))
            else {
                continue
            }
            if HMAC<SHA256>.isValidAuthenticationCode(candidateMac, authenticating: signedContent, using: symmetricKey)
            {
                matched = true
                break
            }
        }
        guard matched else {
            throw AnthropicError.webhookValidation(message: "No matching signature found")
        }

        return try HTTPTransport.decoder.decode(UnwrapWebhookEvent.self, from: Data(payload.utf8))
    }

    private static func decodeSecret(_ key: String) throws -> Data {
        var trimmed = Substring(key)
        if trimmed.hasPrefix(secretPrefix) {
            trimmed.removeFirst(secretPrefix.count)
        }
        guard let data = Data(base64Encoded: trimmed + "=="), !data.isEmpty else {
            throw AnthropicError.webhookValidation(message: "Invalid secret")
        }
        return data
    }
}
