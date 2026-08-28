import Foundation

package struct HTTPTransport: Sendable {
    private static let initialRetryDelay: TimeInterval = 0.5
    private static let maxRetryDelay: TimeInterval = 8.0

    let client: AnthropicClient

    package func send<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        query: [String: String?] = [:],
        body: Body,
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(
                method: method, path: path, query: query, httpBody: try Self.encoder.encode(body),
                contentType: nil, options: options
            )
        }
    }

    /// GET (or any body-less method) with optional query parameters, for the id-cursor/token-cursor
    /// list endpoints and simple retrieve-by-id endpoints. A `nil` query value omits that parameter
    /// entirely, matching the reference SDKs treating unset params as absent rather than `"nil"`.
    /// `arrayQuery` covers list-valued params (e.g. `Files.list`'s `ids`); the reference SDKs
    /// configure their querystring serializer with `array_format="brackets"`, i.e. `ids[]=a&ids[]=b`.
    package func get<Response: Decodable>(
        path: String,
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(
                method: "GET", path: path, query: query, arrayQuery: arrayQuery, httpBody: nil,
                contentType: nil, options: options
            )
        }
    }

    /// POST with an empty `{}` body, for parameter-less action endpoints like
    /// `MessageBatches.cancel` that are semantically actions rather than a plain GET.
    package func post<Response: Decodable>(
        path: String,
        query: [String: String?] = [:],
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(
                method: "POST", path: path, query: query, httpBody: Data("{}".utf8), contentType: nil,
                options: options
            )
        }
    }

    /// DELETE with no body, for the various `*_deleted` endpoints.
    package func delete<Response: Decodable>(
        path: String,
        query: [String: String?] = [:],
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(
                method: "DELETE", path: path, query: query, httpBody: nil, contentType: nil, options: options
            )
        }
    }

    /// GET returning the raw response bytes rather than a JSON-decoded type, for `Files.download`
    /// and `MessageBatches.results` (a `.jsonl` stream the caller splits and decodes line-by-line).
    /// `path` may be a path relative to `client.baseURL` or an absolute URL string -- `results_url`
    /// on a `MessageBatch` is already a full URL returned by the server.
    package func getData(
        path: String,
        query: [String: String?] = [:],
        accept: String? = nil,
        options: RequestOptions
    ) async throws -> Data {
        try await withRetries(options: options) {
            try await performRawRequest(
                method: "GET", path: path, query: query, accept: accept, options: options
            )
        }
    }

    /// POST with a `multipart/form-data` body, for the three upload endpoints (`Files.upload`,
    /// `Skills.create`, `Skills.Versions.create`).
    package func postMultipart<Response: Decodable>(
        path: String,
        query: [String: String?] = [:],
        multipart: MultipartFormData,
        options: RequestOptions
    ) async throws -> Response {
        try await withRetries(options: options) {
            try await performRequest(
                method: "POST", path: path, query: query, httpBody: multipart.encode(),
                contentType: multipart.contentType, options: options
            )
        }
    }

    /// Like `send`, but for SSE endpoints: `body` is pre-encoded (callers typically need to inject
    /// a `"stream": true` field the public param type doesn't expose) and the return is the raw
    /// decoded-SSE sequence rather than a fully-decoded `Response`. Retries, like `send`, only
    /// cover establishing the connection -- once a 200 with a body stream is in hand, failures
    /// while consuming it surface through the stream itself rather than being retried silently.
    package func stream(
        method: String,
        path: String,
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        body: Data,
        options: RequestOptions
    ) async throws -> (response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        try await withRetries(options: options) {
            try await performStreamingRequest(
                method: method, path: path, query: query, arrayQuery: arrayQuery, body: body, options: options
            )
        }
    }

    private func withRetries<T>(
        options: RequestOptions,
        operation: () async throws -> T
    ) async throws -> T {
        let maxRetries = options.maxRetries ?? client.maxRetries
        var attempt = 0
        var didInvalidateCredentials = false
        while true {
            do {
                return try await operation()
            } catch let error as AnthropicError {
                if case .authentication = error, !didInvalidateCredentials {
                    didInvalidateCredentials = true
                    await client.authProvider.invalidate()
                    continue
                }
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
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        httpBody: Data?,
        contentType: String?,
        accept: String? = nil,
        options: RequestOptions
    ) async throws -> URLRequest {
        var request = URLRequest(
            url: Self.applying(
                query: query, arrayQuery: arrayQuery, to: Self.resolvedURL(path, baseURL: client.baseURL)
            )
        )
        request.httpMethod = method
        request.httpBody = httpBody
        request.timeoutInterval = options.timeout ?? client.timeout

        var headers = client.defaultHeaders
        let (headerName, headerValue) = try await client.authProvider.authHeader()
        headers[headerName] = headerValue
        for (key, value) in try await client.authProvider.extraHeaders() {
            headers[key] = value
        }
        if let contentType {
            headers["content-type"] = contentType
        }
        if let accept {
            headers["accept"] = accept
        }
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

    /// `MessageBatch.resultsURL` is already a full URL returned by the server, unlike every other
    /// `path` this transport is called with -- treat any string with a scheme as absolute rather
    /// than re-resolving it against `baseURL`.
    private static func resolvedURL(_ path: String, baseURL: URL) -> URL {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }
        return baseURL.appendingPathComponent(path)
    }

    private static func applying(
        query: [String: String?], arrayQuery: [String: [String]?] = [:], to url: URL
    ) -> URL {
        var queryItems = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        for (key, values) in arrayQuery {
            guard let values else { continue }
            queryItems.append(contentsOf: values.map { URLQueryItem(name: "\(key)[]", value: $0) })
        }
        guard !queryItems.isEmpty else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? url
    }

    private func performRequest<Response: Decodable>(
        method: String,
        path: String,
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        httpBody: Data?,
        contentType: String?,
        options: RequestOptions
    ) async throws -> Response {
        let data = try await performRawRequest(
            method: method, path: path, query: query, arrayQuery: arrayQuery, httpBody: httpBody,
            contentType: contentType, options: options
        )
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func performRawRequest(
        method: String,
        path: String,
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        httpBody: Data? = nil,
        contentType: String? = nil,
        accept: String? = nil,
        options: RequestOptions
    ) async throws -> Data {
        let request = try await buildRequest(
            method: method, path: path, query: query, arrayQuery: arrayQuery, httpBody: httpBody,
            contentType: contentType, accept: accept, options: options
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.urlSession.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AnthropicError.timeout(message: AnthropicError.defaultTimeoutMessage)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
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
        return data
    }

    private func performStreamingRequest(
        method: String,
        path: String,
        query: [String: String?] = [:],
        arrayQuery: [String: [String]?] = [:],
        body: Data,
        options: RequestOptions
    ) async throws -> (response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        let request = try await buildRequest(
            method: method, path: path, query: query, arrayQuery: arrayQuery, httpBody: body, contentType: nil,
            options: options
        )

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await client.urlSession.bytes(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AnthropicError.timeout(message: AnthropicError.defaultTimeoutMessage)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
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

    /// Not `private` so `HTTPTransportRetryTests` can exercise the jitter formula directly rather
    /// than inferring it from elapsed wall-clock time (whose buggy-vs-fixed ranges touch at the
    /// same boundary value and would make a timing-based regression test flaky).
    static func backoffDelay(attempt: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter, retryAfter >= 0, retryAfter <= 60 {
            return retryAfter
        }
        let exponential = min(initialRetryDelay * pow(2.0, Double(attempt - 1)), maxRetryDelay)
        return exponential * (1 - Double.random(in: 0...0.25))
    }

    static let pathComponentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return allowed
    }()

    package static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    package static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension String {
    /// Percent-encodes this string for safe use as a single URL path segment, escaping `/` (and any
    /// other character outside `CharacterSet.urlPathAllowed`) so a caller-supplied id containing a
    /// path separator or `..` can never introduce an extra path segment when interpolated into a
    /// path template like `"v1/files/\(fileId.asPathComponent)"`.
    package var asPathComponent: String {
        addingPercentEncoding(withAllowedCharacters: HTTPTransport.pathComponentAllowed) ?? self
    }
}
