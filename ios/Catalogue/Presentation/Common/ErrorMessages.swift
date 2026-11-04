import Foundation

/// The words customers see when something goes wrong. Owned by the Presentation
/// layer: domain errors say *what* happened, this decides *how to say it*.
enum ErrorMessages {
    static let generic = "Something went wrong. Please try again."

    /// For screens that load products.
    static func loading(_ error: Error) -> String {
        switch error as? CatalogueError {
        case .unreachable?:
            return "We can't reach the catalogue right now. Check your connection and try again."
        case .notFound?:
            return "We couldn't find that. It may have been removed."
        case .serviceUnavailable?:
            return "Products are temporarily unavailable. Please try again shortly."
        case .tooManyRequests?:
            return "Too many requests. Please wait a moment and try again."
        case .invalidEnquiry?, .unexpected?, nil:
            return generic
        }
    }

    /// For the enquiry form, when sending failed for a reason the customer can't fix in the form.
    static func enquiry(_ error: Error) -> String {
        switch error as? CatalogueError {
        case .unreachable?:
            return "We can't reach our server right now. Check your connection and try again."
        case .serviceUnavailable?:
            return "We couldn't send your enquiry. Please try again."
        case .tooManyRequests?:
            return "You've sent several enquiries in a short time. Please try again later."
        case .notFound?:
            return "This product is no longer available."
        case .invalidEnquiry?, .unexpected?, nil:
            return generic
        }
    }

    /// Inline message under a form field.
    static func field(_ field: EnquiryField, _ issue: ValidationIssue) -> String {
        switch (field, issue) {
        case let (_, .rejected(message)):
            return message
        case (.name, .tooLong(let max)):
            return "Name must be \(max) characters or fewer"
        case (.name, _):
            return "Enter your name"
        case (.email, .tooLong(let max)):
            return "Email must be \(max) characters or fewer"
        case (.email, _):
            return "Enter a valid email address"
        case (.phone, _):
            return "Enter a valid phone number"
        case (.message, .tooLong(let max)):
            return "Message must be \(max) characters or fewer"
        case (.message, _):
            return "Check your message"
        }
    }
}

extension Error {
    /// A screen going away mid-request cancels it; that is not an error to show.
    var isCancellation: Bool {
        self is CancellationError
    }
}
