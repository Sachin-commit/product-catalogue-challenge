import Foundation
import UIKit
@testable import Catalogue

// Test doubles for the Domain's repository protocols and the Presentation's
// navigation protocols. View model tests use the real use cases on top of these,
// so they also exercise the rules the use cases apply.

/// A `CatalogueRepository` whose answers each test sets explicitly.
/// Unset endpoints fail loudly so a test never passes by accident.
struct StubCatalogueRepository: CatalogueRepository {
    struct NotStubbed: Error {}

    var featured: @Sendable () async throws -> [Product] = { throw NotStubbed() }
    var categoryList: @Sendable () async throws -> [ProductCategory] = { throw NotStubbed() }
    var listing: @Sendable (String) async throws -> CategoryListing = { _ in throw NotStubbed() }
    var search: @Sendable (SearchQuery) async throws -> [Product] = { _ in throw NotStubbed() }
    var productByID: @Sendable (String) async throws -> Product = { _ in throw NotStubbed() }

    func featuredProducts() async throws -> [Product] { try await featured() }
    func categories() async throws -> [ProductCategory] { try await categoryList() }
    func categoryListing(slug: String) async throws -> CategoryListing { try await listing(slug) }
    func searchProducts(matching query: SearchQuery) async throws -> [Product] { try await search(query) }
    func product(id: String) async throws -> Product { try await productByID(id) }
}

struct StubEnquiryRepository: EnquiryRepository {
    var handler: @Sendable (EnquiryDraft) async throws -> EnquiryReceipt

    func submit(_ enquiry: EnquiryDraft) async throws -> EnquiryReceipt { try await handler(enquiry) }
}

/// Collects values sent from concurrent code so tests can assert on them.
actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []
    func record(_ value: Value) { values.append(value) }
}

/// Records every navigation request a view model makes.
@MainActor
final class NavigatorSpy: HomeNavigating, ProductDetailNavigating, EnquiryNavigating {
    enum Event: Equatable {
        case product(id: String)
        case category(slug: String)
        case search(String)
        case enquiry(productID: String)
        case confirmation(EnquiryConfirmation)
        case closeEnquiry
    }

    private(set) var events: [Event] = []

    func showProduct(_ product: Product) { events.append(.product(id: product.id)) }
    func showCategory(_ category: ProductCategory) { events.append(.category(slug: category.slug)) }
    func showSearchResults(for query: SearchQuery) { events.append(.search(query.text)) }
    func showEnquiry(for product: Product) { events.append(.enquiry(productID: product.id)) }
    func showEnquiryConfirmation(_ confirmation: EnquiryConfirmation) { events.append(.confirmation(confirmation)) }
    func closeEnquiry() { events.append(.closeEnquiry) }
}

/// Never touches the network.
@MainActor
final class StubImageLoader: ImageLoading {
    func image(for url: URL) async -> UIImage? { nil }
}

enum Fixtures {
    static let jackets = ProductCategory(slug: "mens-clothing", name: "Men's Clothing")

    static func product(id: String, title: String = "Product", priceMinor: Int = 1_000) -> Product {
        Product(
            id: id,
            title: title,
            description: "Description",
            category: jackets,
            price: Money(amountMinor: priceMinor, currency: "USD"),
            imageURL: URL(string: "http://localhost:8080/api/v1/products/\(id)/image")!,
            rating: Rating(average: 4.5, count: 10)
        )
    }
}
