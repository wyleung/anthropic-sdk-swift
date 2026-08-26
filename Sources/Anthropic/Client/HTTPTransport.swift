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
        let maxRetries = options.maxRetries ?? client.maxRetries
        var attempt = 0
        while true {
            do {
                return try await performRequest(method: method, path: path, body: body, options: options)
            } catch let error as AnthropicError {
                attempt += 1
                guard attempt <= maxRetries, error.isRetryable else { throw error }
                let delay = Self.backoffDelay(attempt: attempt, retryAfter: error.detail?.retryAfter)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func performRequest<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        body: Body,
        options: RequestOptions
    ) async throws -> Response {
        var request = URLRequest(url: client.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = try Self.encoder.encode(body)
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
