import Foundation

/// A field-level error from the backend's validation (`details` in the error body).
struct FieldError: Decodable, Equatable, Sendable {
    let field: String
    let message: String
}

/// What went wrong talking to the backend, in transport terms. Stays inside the
/// Data layer: repositories translate it to `CatalogueError` (see DomainMapping.swift).
enum APIError: Error, Equatable, Sendable {
    /// No connection, server not running, DNS failure, timeout.
    case cannotReachServer
    /// The backend answered with its standard error body.
    case server(status: Int, code: String, message: String, fieldErrors: [FieldError])
    /// A non-2xx response without our error body (e.g. a proxy error page).
    case unexpectedStatus(Int)
    /// A 2xx response we could not decode: the client and server contracts disagree.
    case invalidResponse
}

/// The backend's single error shape: `{ "error": { code, message, requestId?, details? } }`.
struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
        let requestId: String?
        let details: [FieldError]?
    }

    let error: Body
}
