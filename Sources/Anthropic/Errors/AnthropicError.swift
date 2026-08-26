import Foundation

public struct APIErrorDetail: Sendable {
    public let statusCode: Int?
    public let requestID: String?
    public let workspaceID: String?
    public let type: String?
    public let message: String
    public let body: JSONValue?
    public let retryAfter: TimeInterval?
}

public enum AnthropicError: Error, Sendable {
    case badRequest(APIErrorDetail)
    case authentication(APIErrorDetail)
    case permissionDenied(APIErrorDetail)
    case notFound(APIErrorDetail)
    case conflict(APIErrorDetail)
    case requestTooLarge(APIErrorDetail)
    case unprocessableEntity(APIErrorDetail)
    case rateLimited(APIErrorDetail)
    case serviceUnavailable(APIErrorDetail)
    case overloaded(APIErrorDetail)
    case deadlineExceeded(APIErrorDetail)
    case internalServer(APIErrorDetail)
    case apiStatus(APIErrorDetail)
    case connection(message: String)
    case timeout(message: String)
    case responseValidation(message: String, body: JSONValue?)
    case webhookValidation(message: String)

    public static let defaultConnectionMessage = "Connection error."
    public static let defaultTimeoutMessage =
        "Request timed out or interrupted. This could be due to a network timeout, dropped " +
        "connection, or long-running request. See https://docs.anthropic.com/en/api/errors#long-requests " +
        "for more details."

    public var detail: APIErrorDetail? {
        switch self {
        case .badRequest(let detail), .authentication(let detail), .permissionDenied(let detail),
             .notFound(let detail), .conflict(let detail), .requestTooLarge(let detail),
             .unprocessableEntity(let detail), .rateLimited(let detail), .serviceUnavailable(let detail),
             .overloaded(let detail), .deadlineExceeded(let detail), .internalServer(let detail),
             .apiStatus(let detail):
            return detail
        case .connection, .timeout, .responseValidation, .webhookValidation:
            return nil
        }
    }

    public var statusCode: Int? { detail?.statusCode }

    /// Mirrors the reference SDKs' retry policy: 408/409/429/5xx and connection-level failures.
    public var isRetryable: Bool {
        switch self {
        case .connection, .timeout:
            return true
        default:
            guard let code = statusCode else { return false }
            return code == 408 || code == 409 || code == 429 || (500...599).contains(code)
        }
    }

    static func from(response: HTTPURLResponse, body: JSONValue?) -> AnthropicError {
        let detail = APIErrorDetail(
            statusCode: response.statusCode,
            requestID: response.value(forHTTPHeaderField: "request-id"),
            workspaceID: response.value(forHTTPHeaderField: "anthropic-workspace-id"),
            type: body?["error"]?["type"]?.stringValue,
            message: body?["error"]?["message"]?.stringValue ?? "HTTP \(response.statusCode)",
            body: body,
            retryAfter: response.value(forHTTPHeaderField: "retry-after").flatMap(parseRetryAfter)
        )
        switch response.statusCode {
        case 400: return .badRequest(detail)
        case 401: return .authentication(detail)
        case 403: return .permissionDenied(detail)
        case 404: return .notFound(detail)
        case 409: return .conflict(detail)
        case 413: return .requestTooLarge(detail)
        case 422: return .unprocessableEntity(detail)
        case 429: return .rateLimited(detail)
        case 503: return .serviceUnavailable(detail)
        case 529: return .overloaded(detail)
        case 504: return .deadlineExceeded(detail)
        case 500...599: return .internalServer(detail)
        default: return .apiStatus(detail)
        }
    }

    private static func parseRetryAfter(_ value: String) -> TimeInterval? {
        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSinceNow)
    }
}

extension AnthropicError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connection(let message): return message
        case .timeout(let message): return message
        case .responseValidation(let message, _): return message
        case .webhookValidation(let message): return message
        default: return detail?.message ?? String(describing: self)
        }
    }
}
