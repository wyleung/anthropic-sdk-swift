import Foundation

struct HTTPTransport: Sendable {
    private static let initialRetryDelay: TimeInterval = 0.5
    private static let maxRetryDelay: TimeInterval = 8.0

    let client: AnthropicClient

    func send<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        body: Body,
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(method: method, path: path, body: body, options: options)
        }
    }

    /// Like `send`, but for SSE endpoints: `body` is pre-encoded (callers typically need to inject
    /// a `"stream": true` field the public param type doesn't expose) and the return is the raw
    /// decoded-SSE sequence rather than a fully-decoded `Response`. Retries, like `send`, only
    /// cover establishing the connection -- once a 200 with a body stream is in hand, failures
    /// while consuming it surface through the stream itself rather than being retried silently.
    func stream(
        method: String,
        path: String,
        body: Data,
        options: RequestOptions
    ) async throws -> (response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        try await withRetries(options: options) {
            try await performStreamingRequest(method: method, path: path, body: body, options: options)
        }
    }

    private func withRetries<T>(
        options: RequestOptions,
        operation: () async throws -> T
    ) async throws -> T {
        let maxRetries = options.maxRetries ?? client.maxRetries
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch let error as AnthropicError {
                attempt += 1
                guard attempt <= maxRetries, error.isRetryable else { throw error }
                let delay = Self.backoffDelay(attempt: attempt, retryAfter: error.detail?.retryAfter)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func buildRequest(
        method: String,
        path: String,
        httpBody: Data,
        options: RequestOptions
    ) async throws -> URLRequest {
        var request = URLRequest(url: client.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = httpBody
        request.timeoutInterval = options.timeout ?? client.timeout

        var headers = client.defaultHeaders
        let (headerName, headerValue) = try await client.authProvider.authHeader()
        headers[headerName] = headerValue
        for (key, value) in options.headers {
            if let value {
                headers[key] = value
            } else {
                headers.removeValue(forKey: key)
            }
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func performRequest<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        body: Body,
        options: RequestOptions
    ) async throws -> Response {
        let request = try await buildRequest(
            method: method, path: path, httpBody: try Self.encoder.encode(body), options: options
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.urlSession.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AnthropicError.timeout(message: AnthropicError.defaultTimeoutMessage)
        } catch {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }
        guard (200..<300).contains(http.statusCode) else {
            let errorBody = try? Self.decoder.decode(JSONValue.self, from: data)
            throw AnthropicError.from(response: http, body: errorBody)
        }
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func performStreamingRequest(
        method: String,
        path: String,
        body: Data,
        options: RequestOptions
    ) async throws -> (response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        let request = try await buildRequest(method: method, path: path, httpBody: body, options: options)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await client.urlSession.bytes(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AnthropicError.timeout(message: AnthropicError.defaultTimeoutMessage)
        } catch {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.connection(message: AnthropicError.defaultConnectionMessage)
        }
        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = try? Self.decoder.decode(JSONValue.self, from: errorData)
            throw AnthropicError.from(response: http, body: errorBody)
        }
        return (http, sseEvents(from: sseLines(from: bytes)))
    }

    private static func backoffDelay(attempt: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter, retryAfter >= 0, retryAfter <= 60 {
            return retryAfter
        }
        let exponential = min(initialRetryDelay * pow(2.0, Double(attempt - 1)), maxRetryDelay)
        return exponential + exponential * Double.random(in: 0...0.25)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
