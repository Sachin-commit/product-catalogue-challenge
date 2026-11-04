import Foundation
import Observation

/// Category page state: the category's top rated products, then everything else.
@MainActor
@Observable
final class CategoryViewModel {
    struct Content: Equatable {
        let topRated: [ProductCardModel]
        let more: [ProductCardModel]

        var isEmpty: Bool { topRated.isEmpty && more.isEmpty }
    }

    let category: ProductCategory
    var title: String { category.name }
    var topRatedTitle: String { "Top rated in \(category.name)" }
    var moreTitle: String { "More in \(category.name)" }
    var errorTitle: String { "Couldn't load \(category.name)" }
    let emptyTitle = "No products yet"
    let emptyMessage = "Check back soon."

    private(set) var state: LoadState<Content> = .idle

    private let fetchListing: any FetchCategoryListingUseCase
    @ObservationIgnored private weak var navigator: (any ProductNavigating)?
    @ObservationIgnored private var productsByID: [String: Product] = [:]

    init(category: ProductCategory, fetchListing: any FetchCategoryListingUseCase, navigator: (any ProductNavigating)?) {
        self.category = category
        self.fetchListing = fetchListing
        self.navigator = navigator
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let listing = try await fetchListing.execute(category: category)
            productsByID = Dictionary(
                (listing.topRated + listing.more).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            state = .loaded(Content(
                topRated: listing.topRated.map { ProductCardModel($0) },
                more: listing.more.map { ProductCardModel($0) }
            ))
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
