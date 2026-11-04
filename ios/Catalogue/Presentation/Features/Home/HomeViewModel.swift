import Foundation
import Observation

/// Home screen state and actions: the owner's featured products, the category
/// links, and the search box. No UIKit: the view controller renders this.
@MainActor
@Observable
final class HomeViewModel {
    struct Content: Equatable {
        let featured: [ProductCardModel]
        let categories: [ProductCategory]
    }

    let featuredTitle = "Top rated"
    let featuredSubtitle = "Hand-picked favourites"
    let categoriesTitle = "Shop by category"
    let errorTitle = "Couldn't load the catalogue"

    private(set) var state: LoadState<Content> = .idle
    var searchText = ""

    /// The Search button is enabled only when there is something to search for.
    var canSearch: Bool { SearchQuery(searchText) != nil }

    private let fetchHomeContent: any FetchHomeContentUseCase
    @ObservationIgnored private weak var navigator: (any HomeNavigating)?
    @ObservationIgnored private var productsByID: [String: Product] = [:]

    init(fetchHomeContent: any FetchHomeContentUseCase, navigator: (any HomeNavigating)?) {
        self.fetchHomeContent = fetchHomeContent
        self.navigator = navigator
    }

    /// Loads once; coming back to the home screen does not refetch.
    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let content = try await fetchHomeContent.execute()
            productsByID = Dictionary(content.featured.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            state = .loaded(Content(
                featured: content.featured.map { ProductCardModel($0) },
                categories: content.categories
            ))
        } catch let error where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            state = .failed(message: ErrorMessages.loading(error))
        }
    }

    func search() {
        guard let query = SearchQuery(searchText) else { return }
        navigator?.showSearchResults(for: query)
    }

    func selectProduct(id: ProductCardModel.ID) {
        guard let product = productsByID[id] else { return }
        navigator?.showProduct(product)
    }

    func selectCategory(_ category: ProductCategory) {
        navigator?.showCategory(category)
    }
}
