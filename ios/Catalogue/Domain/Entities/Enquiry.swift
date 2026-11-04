import Foundation

/// The fields a customer fills in on the enquiry form.
enum EnquiryField: String, CaseIterable, Hashable, Sendable {
    case name, email, phone, message
}

/// Why a field was not accepted.
enum ValidationIssue: Equatable, Sendable {
    case missing
    case invalidFormat
    case tooLong(max: Int)
    /// The backend rejected the field with its own explanation.
    case rejected(message: String)
}

/// An enquiry as the customer wrote it, normalised: text is trimmed and
/// blank optional fields become nil. Validity is checked by `EnquiryValidator`.
struct EnquiryDraft: Equatable, Sendable {
    let productId: String
    let name: String
    let email: String
    let phone: String?
    let message: String?

    init(productId: String, name: String, email: String, phone: String = "", message: String = "") {
        self.productId = productId
        self.name = Self.normalised(name) ?? ""
        self.email = Self.normalised(email) ?? ""
        self.phone = Self.normalised(phone)
        self.message = Self.normalised(message)
    }

    private static func normalised(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Returned once the sales team's inbox has accepted the enquiry email.
struct EnquiryReceipt: Equatable, Sendable {
    let reference: String
}
