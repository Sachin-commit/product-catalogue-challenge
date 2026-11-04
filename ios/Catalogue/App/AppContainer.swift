import Foundation

/// Composition root: the one place that decides which implementation backs each
/// abstraction (repositories, use cases, image loading). Everything else receives
/// its dependencies through its initialiser. Swapping the backend for a cache,
/// or the network for test doubles, is a change here.
@MainActor
final class AppContainer {
    let imageLoader: any ImageLoading
    let fetchHomeContent: any FetchHomeContentUseCase
    let fetchCategoryListing: any FetchCategoryListingUseCase
    let searchProducts: any SearchProductsUseCase
    let fetchProduct: any FetchProductUseCase
    let submitEnquiry: any SubmitEnquiryUseCase

    init(catalogue: any CatalogueRepository, enquiries: any EnquiryRepository, imageLoader: any ImageLoading) {
        self.imageLoader = imageLoader
        fetchHomeContent = DefaultFetchHomeContentUseCase(repository: catalogue)
        fetchCategoryListing = DefaultFetchCategoryListingUseCase(repository: catalogue)
        searchProducts = DefaultSearchProductsUseCase(repository: catalogue)
        fetchProduct = DefaultFetchProductUseCase(repository: catalogue)
        submitEnquiry = DefaultSubmitEnquiryUseCase(repository: enquiries)
    }

    /// The real app: talks to our backend at the configured URL.
    static func live(configuration: AppConfiguration) -> AppContainer {
        let http = HTTPClient(baseURL: configuration.apiBaseURL)
        return AppContainer(
            catalogue: RemoteCatalogueRepository(http: http),
            enquiries: RemoteEnquiryRepository(http: http),
            imageLoader: ImageLoader()
        )
    }
}
