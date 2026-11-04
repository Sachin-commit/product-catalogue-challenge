import Foundation
import Observation

/// Product page state. Shows the product the customer tapped straight away,
/// then refreshes it, because this is the page they enquire from.
@MainActor
@Observable
final class ProductDetailViewModel {
    let aboutTitle = "About this product"
    let enquireTitle = "Enquire"

    private(set) var product: Product
    private(set) var isRefreshing = false

    /// Everything the screen shows, already formatted.
    var display: ProductDetailModel { ProductDetailModel(product) }

    private let fetchProduct: any FetchProductUseCase
    @ObservationIgnored private weak var navigator: (any ProductDetailNavigating)?

    init(product: Product, fetchProduct: any FetchProductUseCase, navigator: (any ProductDetailNavigating)?) {
        self.product = product
        self.fetchProduct = fetchProduct
        self.navigator = navigator
    }

    /// Fetches the latest details (e.g. price) by id. If that fails we keep showing
    /// what we already have: slightly stale details beat an error screen here.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let latest = try? await fetchProduct.execute(id: product.id) {
            product = latest
        }
    }

    func enquire() {
        navigator?.showEnquiry(for: product)
    }
}
