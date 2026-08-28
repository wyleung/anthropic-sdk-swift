import Foundation

/// `POST {baseURL}/v1/oauth/token` -- shared wire logic for the two grant types the reference SDKs
/// support: `urn:ietf:params:oauth:grant-type:jwt-bearer` (Workload Identity Federation) and
/// `refresh_token` (`user_oauth` profiles with a `client_id`).
enum OAuthTokenEndpoint {
    static let path = "/v1/oauth/token"
    static let oauthBetaHeader = "oauth-2025-04-20"
    static let federationBetaHeader = "oidc-federation-2026-04-01"
    static let maxAssertionBytes = 16 * 1024
    static let maxResponseBytes = 1 << 20

    /// The jwt-bearer grant. Sends both beta headers (comma-joined, no space) -- the federation
    /// marker would misroute a refresh-token call or an ordinary Bearer-authenticated API request,
    /// so it's scoped to this one call site.
    static func exchangeJWTBearer(
        baseURL: URL,
        assertion: String,
        federationRuleId: String,
        organizationId: String,
        serviceAccountId: String?,
        workspaceId: String?,
        urlSession: URLSession
    ) async throws -> AccessToken {
        guard assertion.utf8.count <= maxAssertionBytes else {
            throw AnthropicError.responseValidation(
                message: "Identity token assertion exceeds the 16 KiB limit.", body: nil
            )
        }
        var body: [String: Any] = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
            "federation_rule_id": federationRuleId,
            "organization_id": organizationId,
        ]
        if let serviceAccountId { body["service_account_id"] = serviceAccountId }
        if let workspaceId { body["workspace_id"] = workspaceId }

        let betaHeader = "\(oauthBetaHeader),\(federationBetaHeader)"
        let (data, http) = try await post(baseURL: baseURL, body: body, betaHeader: betaHeader, urlSession: urlSession)
        guard (200..<300).contains(http.statusCode) else { throw tokenEndpointError(status: http.statusCode, data: data) }

        let payload = try decodeResponse(data)
        guard let expiresIn = payload.expiresIn else {
            throw AnthropicError.responseValidation(
                message: "OAuth token endpoint response is missing expires_in.", body: nil
            )
        }
        return AccessToken(
            accessToken: payload.accessToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            refreshToken: payload.refreshToken
        )
    }

    /// The refresh_token grant. `expires_in` defaults to 3600 when absent (unlike the jwt-bearer
    /// grant, where it's required), and a server that doesn't rotate the refresh token gets the old
    /// one carried forward.
    static func exchangeRefreshToken(
        baseURL: URL,
        refreshToken: String,
        clientId: String,
        urlSession: URLSession
    ) async throws -> AccessToken {
        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ]
        let (data, http) = try await post(baseURL: baseURL, body: body, betaHeader: oauthBetaHeader, urlSession: urlSession)
        guard (200..<300).contains(http.statusCode) else { throw tokenEndpointError(status: http.statusCode, data: data) }

        let payload = try decodeResponse(data)
        let expiresIn = payload.expiresIn ?? 3600
        return AccessToken(
            accessToken: payload.accessToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            refreshToken: payload.refreshToken ?? refreshToken
        )
    }

    private struct ResponsePayload {
        let accessToken: String
        let expiresIn: Double?
        let refreshToken: String?
    }

    private static func post(
        baseURL: URL, body: [String: Any], betaHeader: String, urlSession: URLSession
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AnthropicError.timeout(message: AnthropicError.defaultTimeoutMessage)
        } catch {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }
        guard data.count <= maxResponseBytes else {
            throw AnthropicError.responseValidation(
                message: "OAuth token endpoint response exceeded the 1 MiB limit.", body: nil
            )
        }
        return (data, http)
    }

    private static func decodeResponse(_ data: Data) throws -> ResponsePayload {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AnthropicError.responseValidation(
                message: "OAuth token endpoint returned a non-JSON-object body.", body: nil
            )
        }
        guard let accessToken = object["access_token"] as? String else {
            throw AnthropicError.responseValidation(
                message: "OAuth token endpoint response is missing access_token.", body: nil
            )
        }
        if let tokenType = object["token_type"] as? String, tokenType.caseInsensitiveCompare("Bearer") != .orderedSame {
            throw AnthropicError.responseValidation(
                message: "OAuth token endpoint returned unexpected token_type \"\(tokenType)\".", body: nil
            )
        }
        let expiresIn = (object["expires_in"] as? NSNumber)?.doubleValue
        return ResponsePayload(
            accessToken: accessToken, expiresIn: expiresIn, refreshToken: object["refresh_token"] as? String
        )
    }

    /// Non-2xx bodies are redacted to just `error`/`error_description`/`error_uri` before being
    /// wrapped in an error, matching the reference SDKs -- the raw body may otherwise echo the
    /// assertion or other sensitive request fields back.
    private static func tokenEndpointError(status: Int, data: Data) -> AnthropicError {
        let allowedKeys: Set<String> = ["error", "error_description", "error_uri"]
        var redacted: [String: JSONValue] = [:]
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            for (key, value) in object where allowedKeys.contains(key) {
                if let stringValue = value as? String {
                    redacted[key] = .string(stringValue)
                }
            }
        }
        var message = "OAuth token endpoint returned HTTP \(status)."
        if let description = redacted["error_description"]?.stringValue {
            message += " \(description)"
        }
        if status == 401 {
            message += " Check the federation rule, organization/workspace scoping, and the " +
                "Console auth-event log."
        }
        return .authentication(APIErrorDetail(
            statusCode: status,
            requestID: nil,
            workspaceID: nil,
            type: redacted["error"]?.stringValue,
            message: message,
            body: .object(redacted),
            retryAfter: nil,
            shouldRetryHeader: nil
        ))
    }
}
