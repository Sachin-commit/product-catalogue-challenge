import UIKit

/// Sample data and in-memory repositories for Xcode previews (`#Preview`), so
/// designers can iterate on screens without the backend. Not used by the running app.
/// It also shows the layering paying off: previews swap the Data layer, nothing else.
enum PreviewData {
    static let categories = [
        ProductCategory(slug: "mens-clothing", name: "Men's Clothing"),
        ProductCategory(slug: "electronics", name: "Electronics"),
    ]

    static let products: [Product] = [
        Product(
            id: "3",
            title: "Mens Cotton Jacket",
            description: "Great outerwear jackets for Spring/Autumn/Winter, suitable for many occasions.",
            category: categories[0],
            price: Money(amountMinor: 5599, currency: "USD"),
            imageURL: URL(string: "http://localhost:8080/api/v1/products/3/image")!,
            rating: Rating(average: 4.7, count: 500)
        ),
        Product(
            id: "11",
            title: "Silicon Power 256GB SSD 3D NAND A55 SLC Cache Performance Boost SATA III 2.5",
            description: "3D NAND flash are applied to deliver high transfer speeds.",
            category: categories[1],
            price: Money(amountMinor: 10900, currency: "USD"),
            imageURL: URL(string: "http://localhost:8080/api/v1/products/11/image")!,
            rating: Rating(average: 4.8, count: 319)
        ),
    ]

    // Real use cases over in-memory repositories.
    static let fetchHomeContent = DefaultFetchHomeContentUseCase(repository: PreviewCatalogueRepository())
    static let fetchProduct = DefaultFetchProductUseCase(repository: PreviewCatalogueRepository())
    static let submitEnquiry = DefaultSubmitEnquiryUseCase(repository: PreviewEnquiryRepository())
    @MainActor static let imageLoader: any ImageLoading = PreviewImageLoader()
}

private struct PreviewCatalogueRepository: CatalogueRepository {
    func featuredProducts() async throws -> [Product] { PreviewData.products }
    func categories() async throws -> [ProductCategory] { PreviewData.categories }
    func categoryListing(slug: String) async throws -> CategoryListing {
        let category = PreviewData.categories.first { $0.slug == slug } ?? PreviewData.categories[0]
        return CategoryListing(category: category, topRated: PreviewData.products, more: PreviewData.products)
    }
    func searchProducts(matching query: SearchQuery) async throws -> [Product] { PreviewData.products }
    func product(id: String) async throws -> Product {
        PreviewData.products.first { $0.id == id } ?? PreviewData.products[0]
    }
}

private struct PreviewEnquiryRepository: EnquiryRepository {
    func submit(_ enquiry: EnquiryDraft) async throws -> EnquiryReceipt {
        try await Task.sleep(for: .seconds(1))
        return EnquiryReceipt(reference: "ENQ-PREVIEW1")
    }
}

/// Draws a placeholder instead of downloading.
@MainActor
private final class PreviewImageLoader: ImageLoading {
    func image(for url: URL) async -> UIImage? {
        UIImage(systemName: "photo.artframe")
    }
}
