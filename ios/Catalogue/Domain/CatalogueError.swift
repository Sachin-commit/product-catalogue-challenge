import Foundation

/// Failures the app understands, independent of how data is fetched.
/// The Data layer translates transport errors (HTTP status codes, URL errors)
/// into these; the Presentation layer turns them into words for the customer.
/// Cancellation is not one of these: it surfaces as Swift's `CancellationError`.
enum CatalogueError: Error, Equatable, Sendable {
    /// No connection, the server isn't running, or it took too long.
    case unreachable
    case notFound
    case invalidEnquiry([EnquiryField: ValidationIssue])
    case tooManyRequests
    /// The service or one of its providers (product source, email) failed.
    case serviceUnavailable
    /// Anything we did not expect, e.g. a response we could not read.
    case unexpected
}
