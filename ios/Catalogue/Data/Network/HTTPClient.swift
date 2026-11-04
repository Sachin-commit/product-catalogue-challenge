import Foundation

/// Thin JSON-over-HTTP client. Knows about our error shape but nothing about products.
struct HTTPClient: Sendable {
    /// Performs one request. Injected so tests can answer without a network or global stubs.
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let baseURL: URL
    private let transport: Transport

    init(baseURL: URL, transport: @escaping Transport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    init(baseURL: URL, session: URLSession = .shared) {
        self.init(baseURL: baseURL) { request in try await session.data(for: request) }
    }

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try await send(makeRequest(path: path, query: query, method: "GET", body: nil))
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let data = try JSONEncoder().encode(body)
        return try await send(makeRequest(path: path, query: [], method: "POST", body: data))
    }

    func makeRequest(path: String, query: [URLQueryItem], method: String, body: Data?) -> URLRequest {
        var url = baseURL.appending(path: path)
        if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Encode values strictly: Foundation leaves "+" alone, but servers decode it as a space,
            // so a search for "c++" would otherwise arrive as "c  ".
            components.percentEncodedQueryItems = query.map { item in
                URLQueryItem(
                    name: item.name,
                    value: item.value?.addingPercentEncoding(withAllowedCharacters: .strictQueryValue)
                )
            }
            url = components.url ?? url
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let result: (Data, URLResponse)
        do {
            result = try await transport(request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.cannotReachServer
        }
        let (data, response) = result

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw APIError.server(
                    status: http.statusCode,
                    code: envelope.error.code,
                    message: envelope.error.message,
                    fieldErrors: envelope.error.details ?? []
                )
            }
            throw APIError.unexpectedStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}

extension CharacterSet {
    /// Characters allowed unescaped in a query *value*: excludes the separators `&`, `=`, `+`, `#`, `?`.
    static let strictQueryValue: CharacterSet = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#?"))
}
