import Foundation
import Observation

/// Results for one search query.
@MainActor
@Observable
final class SearchViewModel {
    let query: SearchQuery
    let title = "Search"
    var resultsTitle: String { "Results for “\(query.text)”" }
    var emptyMessage: String { "No products match “\(query.text)”. Try a different word." }
    let errorTitle = "Search failed"

    private(set) var state: LoadState<[ProductCardModel]> = .idle

    private let searchProducts: any SearchProductsUseCase
    @ObservationIgnored private weak var navigator: (any ProductNavigating)?
    @ObservationIgnored private var productsByID: [String: Product] = [:]

    init(query: SearchQuery, searchProducts: any SearchProductsUseCase, navigator: (any ProductNavigating)?) {
        self.query = query
        self.searchProducts = searchProducts
        self.navigator = navigator
    }

    func resultsSummary(count: Int) -> String {
        count == 1 ? "1 product" : "\(count) products"
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let products = try await searchProducts.execute(query: query)
            productsByID = Dictionary(products.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            state = .loaded(products.map { ProductCardModel($0) })
        } catch let error where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            state = .failed(message: ErrorMessages.loading(error))
        }
    }

    func selectProduct(id: ProductCardModel.ID) {
        guard let product = productsByID[id] else { return }
        navigator?.showProduct(product)
    }
}
