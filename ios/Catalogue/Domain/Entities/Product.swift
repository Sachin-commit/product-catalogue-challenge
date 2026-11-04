import Foundation

// Domain entities: plain values that describe the business, with no knowledge of
// JSON, HTTP or UIKit. The Data layer maps API responses into these; the
// Presentation layer formats them for display. Changing either side does not
// change these types.

struct ProductCategory: Hashable, Identifiable, Sendable {
    let slug: String
    let name: String

    var id: String { slug }
}

struct Money: Hashable, Sendable {
    /// Integer amount in the currency's minor unit (cents), so no float rounding.
    let amountMinor: Int
    /// ISO 4217 code, e.g. "USD".
    let currency: String
}

struct Rating: Hashable, Sendable {
    /// Average customer rating, 0–5.
    let average: Double
    let count: Int
}

struct Product: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let category: ProductCategory
    let price: Money
    let imageURL: URL
    let rating: Rating?
}

/// What the home screen needs: the owner's featured picks and the categories to browse.
struct HomeContent: Equatable, Sendable {
    let featured: [Product]
    let categories: [ProductCategory]
}

/// One category's products, split into the "top rated" strip and everything else.
struct CategoryListing: Equatable, Sendable {
    let category: ProductCategory
    let topRated: [Product]
    let more: [Product]
}
