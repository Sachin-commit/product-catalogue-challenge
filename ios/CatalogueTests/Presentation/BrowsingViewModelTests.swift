import Foundation
import Testing
@testable import Catalogue

@MainActor
struct HomeViewModelTests {
    private func makeModel(_ repository: StubCatalogueRepository, navigator: NavigatorSpy = NavigatorSpy()) -> HomeViewModel {
        HomeViewModel(fetchHomeContent: DefaultFetchHomeContentUseCase(repository: repository), navigator: navigator)
    }

    private func repository(featured: [Product] = [Fixtures.product(id: "1")]) -> StubCatalogueRepository {
        var repository = StubCatalogueRepository()
        repository.featured = { featured }
        repository.categoryList = { [Fixtures.jackets] }
        return repository
    }

    @Test func showsTheFeaturedProductsAsCardsAndTheCategories() async {
        let featured = (1...5).map { Fixtures.product(id: "\($0)") }
        let model = makeModel(repository(featured: featured))

        await model.load()

        #expect(model.state == .loaded(.init(featured: featured.map { ProductCardModel($0) }, categories: [Fixtures.jackets])))
    }

    @Test func showsAReadableErrorWhenTheCatalogueCannotBeReached() async {
        var failing = repository()
        failing.featured = { throw CatalogueError.unreachable }
        let model = makeModel(failing)

        await model.load()

        #expect(model.state == .failed(message: ErrorMessages.loading(CatalogueError.unreachable)))
    }

    @Test func loadsOnlyOnce() async {
        let calls = Recorder<Int>()
        var counting = repository()
        counting.featured = {
            await calls.record(1)
            return [Fixtures.product(id: "1")]
        }
        let model = makeModel(counting)

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        #expect(await calls.values.count == 1)
    }

    @Test func enablesSearchOnlyWhenThereIsSomethingToSearchFor() {
        let model = makeModel(repository())
        #expect(model.canSearch == false)
        model.searchText = "   "
        #expect(model.canSearch == false)
        model.searchText = " jacket "
        #expect(model.canSearch)
    }

    @Test func searchingNavigatesWithTheCleanedUpTerm() {
        let navigator = NavigatorSpy()
        let model = makeModel(repository(), navigator: navigator)

        model.searchText = "   "
        model.search()
        model.searchText = "  jacket "
        model.search()

        #expect(navigator.events == [.search("jacket")])
    }

    @Test func selectingAProductOrCategoryNavigates() async {
        let navigator = NavigatorSpy()
        let model = makeModel(repository(featured: [Fixtures.product(id: "3")]), navigator: navigator)
        await model.load()

        model.selectProduct(id: "3")
        model.selectProduct(id: "unknown")
        model.selectCategory(Fixtures.jackets)

        #expect(navigator.events == [.product(id: "3"), .category(slug: "mens-clothing")])
    }
}

@MainActor
struct CategoryViewModelTests {
    @Test func splitsTheListingIntoTopRatedAndMore() async {
        let requested = Recorder<String>()
        var repository = StubCatalogueRepository()
        repository.listing = { slug in
            await requested.record(slug)
            return CategoryListing(category: Fixtures.jackets, topRated: [Fixtures.product(id: "1")], more: [Fixtures.product(id: "2")])
        }
        let model = CategoryViewModel(
            category: Fixtures.jackets,
            fetchListing: DefaultFetchCategoryListingUseCase(repository: repository),
            navigator: nil
        )

        await model.load()

        #expect(model.state.value?.topRated.map(\.id) == ["1"])
        #expect(model.state.value?.more.map(\.id) == ["2"])
        #expect(model.topRatedTitle == "Top rated in Men's Clothing")
        #expect(await requested.values == ["mens-clothing"])
    }

    @Test func treatsCancellationAsNotAnError() async {
        var repository = StubCatalogueRepository()
        repository.listing = { _ in throw CancellationError() }
        let model = CategoryViewModel(
            category: Fixtures.jackets,
            fetchListing: DefaultFetchCategoryListingUseCase(repository: repository),
            navigator: nil
        )

        await model.load()

        #expect(model.state == .idle)
    }
}

@MainActor
struct SearchViewModelTests {
    @Test func searchesForTheQueryAndShowsResults() async throws {
        let queries = Recorder<String>()
        var repository = StubCatalogueRepository()
        repository.search = { query in
            await queries.record(query.text)
            return [Fixtures.product(id: "1", title: "Backpack")]
        }
        let navigator = NavigatorSpy()
        let model = SearchViewModel(
            query: try #require(SearchQuery("backpack")),
            searchProducts: DefaultSearchProductsUseCase(repository: repository),
            navigator: navigator
        )

        await model.load()
        model.selectProduct(id: "1")

        #expect(await queries.values == ["backpack"])
        #expect(model.state.value?.map(\.title) == ["Backpack"])
        #expect(model.resultsTitle == "Results for “backpack”")
        #expect(navigator.events == [.product(id: "1")])
    }

    @Test func noMatchesIsAnEmptyResultNotAnError() async throws {
        var repository = StubCatalogueRepository()
        repository.search = { _ in [] }
        let model = SearchViewModel(
            query: try #require(SearchQuery("zzz")),
            searchProducts: DefaultSearchProductsUseCase(repository: repository),
            navigator: nil
        )

        await model.load()

        #expect(model.state == .loaded([]))
    }
}

@MainActor
struct ProductDetailViewModelTests {
    @Test func showsTheTappedProductImmediatelyThenRefreshes() async {
        let tapped = Fixtures.product(id: "3", priceMinor: 5_000)
        let latest = Fixtures.product(id: "3", priceMinor: 5_599)
        var repository = StubCatalogueRepository()
        repository.productByID = { _ in latest }
        let model = ProductDetailViewModel(product: tapped, fetchProduct: DefaultFetchProductUseCase(repository: repository), navigator: nil)

        #expect(model.display == ProductDetailModel(tapped))
        await model.refresh()
        #expect(model.display == ProductDetailModel(latest))
    }

    @Test func keepsTheTappedProductIfTheRefreshFails() async {
        let tapped = Fixtures.product(id: "3")
        var repository = StubCatalogueRepository()
        repository.productByID = { _ in throw CatalogueError.unreachable }
        let model = ProductDetailViewModel(product: tapped, fetchProduct: DefaultFetchProductUseCase(repository: repository), navigator: nil)

        await model.refresh()

        #expect(model.product == tapped)
        #expect(model.isRefreshing == false)
    }

    @Test func enquiringNavigatesToTheEnquiryForm() {
        let navigator = NavigatorSpy()
        let model = ProductDetailViewModel(
            product: Fixtures.product(id: "3"),
            fetchProduct: DefaultFetchProductUseCase(repository: StubCatalogueRepository()),
            navigator: navigator
        )

        model.enquire()

        #expect(navigator.events == [.enquiry(productID: "3")])
    }
}

struct ProductFormatterTests {
    private let formatter = ProductFormatter(locale: Locale(identifier: "en_US"))

    @Test func formatsPricesFromMinorUnits() {
        #expect(formatter.price(Money(amountMinor: 5599, currency: "USD")) == "$55.99")
        #expect(formatter.price(Money(amountMinor: 69500, currency: "USD")) == "$695.00")
    }

    @Test func formatsRatings() {
        let rating = Rating(average: 4.7, count: 500)
        #expect(formatter.ratingText(rating) == "4.7 (500)")
        #expect(formatter.ratingAccessibilityLabel(rating) == "Rated 4.7 out of 5 from 500 reviews")
    }

    @Test func cardCombinesEverythingForVoiceOver() {
        let card = ProductCardModel(Fixtures.product(id: "1", title: "Backpack", priceMinor: 10995), formatter: formatter)
        #expect(card.accessibilityLabel == "Backpack, $109.95, Rated 4.5 out of 5 from 10 reviews")
    }
}
