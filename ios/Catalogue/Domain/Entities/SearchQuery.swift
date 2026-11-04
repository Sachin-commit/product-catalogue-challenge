import Foundation

/// A search term that is safe to send: trimmed, never blank, and within the
/// backend's 100-character limit. If you have a `SearchQuery`, it is valid.
struct SearchQuery: Hashable, Sendable {
    static let maxLength = 100

    let text: String

    /// Returns nil for input that has nothing to search for (empty or whitespace).
    init?(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        text = String(trimmed.prefix(Self.maxLength))
    }
}
