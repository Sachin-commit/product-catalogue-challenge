import Foundation

/// The business rules for an enquiry. They mirror the backend's rules so customers
/// get instant feedback; the backend still validates everything and is the source of truth.
struct EnquiryValidator: Sendable {
    static let nameMaxLength = 100
    static let emailMaxLength = 254
    static let messageMaxLength = 2000

    /// Returns an issue for each invalid field; empty means the draft can be sent.
    func validate(_ draft: EnquiryDraft) -> [EnquiryField: ValidationIssue] {
        var issues: [EnquiryField: ValidationIssue] = [:]

        if draft.name.isEmpty {
            issues[.name] = .missing
        } else if draft.name.count > Self.nameMaxLength {
            issues[.name] = .tooLong(max: Self.nameMaxLength)
        }

        if draft.email.isEmpty {
            issues[.email] = .missing
        } else if !draft.email.matchesPattern(#"^[^\s@]+@[^\s@]+\.[^\s@]+$"#) {
            issues[.email] = .invalidFormat
        } else if draft.email.count > Self.emailMaxLength {
            issues[.email] = .tooLong(max: Self.emailMaxLength)
        }

        if let phone = draft.phone, !phone.matchesPattern(#"^\+?[0-9 ()-]{6,20}$"#) {
            issues[.phone] = .invalidFormat
        }

        if let message = draft.message, message.count > Self.messageMaxLength {
            issues[.message] = .tooLong(max: Self.messageMaxLength)
        }

        return issues
    }
}

private extension String {
    func matchesPattern(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
