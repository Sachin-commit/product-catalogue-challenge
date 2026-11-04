import Foundation

// One use case per thing a customer can do. View models depend on these
// protocols (not on repositories or networking), each with a single method
// (single responsibility, interface segregation). Several are thin today; they
// are where rules go as the product grows (e.g. personalised featured products).

protocol FetchHomeContentUseCase: Sendable {
    func execute() async throws -> HomeContent
}

protocol FetchCategoryListingUseCase: Sendable {
    func execute(category: ProductCategory) async throws -> CategoryListing
}

protocol SearchProductsUseCase: Sendable {
    func execute(query: SearchQuery) async throws -> [Product]
}

protocol FetchProductUseCase: Sendable {
    func execute(id: String) async throws -> Product
}

protocol SubmitEnquiryUseCase: Sendable {
    /// Validates first and throws `CatalogueError.invalidEnquiry` without sending if anything is wrong.
    func execute(_ draft: EnquiryDraft) async throws -> EnquiryReceipt
}

// MARK: - Implementations

struct DefaultFetchHomeContentUseCase: FetchHomeContentUseCase {
    let repository: any CatalogueRepository

    /// Featured products and categories load in parallel; if either fails, the whole thing fails,
    /// so the home screen shows one error with a retry rather than a half-empty page.
    func execute() async throws -> HomeContent {
        async let featured = repository.featuredProducts()
        async let categories = repository.categories()
        return HomeContent(featured: try await featured, categories: try await categories)
    }
}

struct DefaultFetchCategoryListingUseCase: FetchCategoryListingUseCase {
    let repository: any CatalogueRepository

    func execute(category: ProductCategory) async throws -> CategoryListing {
        try await repository.categoryListing(slug: category.slug)
    }
}

struct DefaultSearchProductsUseCase: SearchProductsUseCase {
    let repository: any CatalogueRepository

    /// Matching is done by the backend so every client gets the same results.
    func execute(query: SearchQuery) async throws -> [Product] {
        try await repository.searchProducts(matching: query)
    }
}

struct DefaultFetchProductUseCase: FetchProductUseCase {
    let repository: any CatalogueRepository

    func execute(id: String) async throws -> Product {
        try await repository.product(id: id)
    }
}

struct DefaultSubmitEnquiryUseCase: SubmitEnquiryUseCase {
    let repository: any EnquiryRepository
    var validator = EnquiryValidator()

    func execute(_ draft: EnquiryDraft) async throws -> EnquiryReceipt {
        let issues = validator.validate(draft)
        guard issues.isEmpty else { throw CatalogueError.invalidEnquiry(issues) }
        return try await repository.submit(draft)
    }
}
