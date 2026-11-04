import Foundation

// Repository protocols are owned by the Domain layer and implemented by the Data
// layer (dependency inversion): use cases never know whether data comes from our
// API, a cache or a test stub. They are split by responsibility (interface
// segregation): browsing reads products, enquiries only write.
// Implementations throw `CatalogueError` (or `CancellationError`).

protocol CatalogueRepository: Sendable {
    func featuredProducts() async throws -> [Product]
    func categories() async throws -> [ProductCategory]
    func categoryListing(slug: String) async throws -> CategoryListing
    func searchProducts(matching query: SearchQuery) async throws -> [Product]
    func product(id: String) async throws -> Product
}

protocol EnquiryRepository: Sendable {
    func submit(_ enquiry: EnquiryDraft) async throws -> EnquiryReceipt
}
