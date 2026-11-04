import Foundation
import Testing
import UIKit
@testable import Catalogue

/// Records what a render closure saw, so tests can check screens re-render on change.
@MainActor
private final class RenderLog {
    var states: [LoadState<[ProductCardModel]>] = []
}

/// Lets queued main-actor work (re-renders scheduled by `renderOnChange`) run.
@MainActor
private func settle(until done: () -> Bool) async {
    for _ in 0..<100 where !done() {
        await Task.yield()
    }
}

@MainActor
struct ObservationRenderingTests {
    @Test func rendersAgainWhenAnObservedViewModelPropertyChanges() async throws {
        var repository = StubCatalogueRepository()
        repository.search = { _ in [Fixtures.product(id: "1")] }
        let model = SearchViewModel(
            query: try #require(SearchQuery("backpack")),
            searchProducts: DefaultSearchProductsUseCase(repository: repository),
            navigator: nil
        )
        let log = RenderLog()

        renderOnChange { log.states.append(model.state) }
        await model.load()
        await settle { log.states.last?.value != nil }

        #expect(log.states.first == .idle)
        #expect(log.states.last?.value?.map(\.id) == ["1"])
    }
}

/// The view controller is a passive view: it renders the view model and forwards taps to it.
@MainActor
struct HomeViewControllerTests {
    private func makeScreen(featured: [Product], navigator: NavigatorSpy) -> (HomeViewController, HomeViewModel) {
        var repository = StubCatalogueRepository()
        repository.featured = { featured }
        repository.categoryList = { [Fixtures.jackets] }
        let model = HomeViewModel(fetchHomeContent: DefaultFetchHomeContentUseCase(repository: repository), navigator: navigator)
        return (HomeViewController(model: model, imageLoader: StubImageLoader()), model)
    }

    @Test func showsTheFiveFeaturedProductsAndTheCategoryLinks() async {
        let featured = (1...5).map { Fixtures.product(id: "\($0)") }
        let (screen, model) = makeScreen(featured: featured, navigator: NavigatorSpy())

        screen.loadViewIfNeeded()
        await model.load()
        await settle { screen.dataSource.snapshot().numberOfItems > 0 }

        let snapshot = screen.dataSource.snapshot()
        #expect(snapshot.itemIdentifiers(inSection: .featured) == featured.map { HomeViewController.Item.product(ProductCardModel($0)) })
        #expect(snapshot.itemIdentifiers(inSection: .categories) == [.category(Fixtures.jackets)])
    }

    @Test func tappingAFeaturedProductAsksTheViewModelToOpenIt() async {
        let navigator = NavigatorSpy()
        let (screen, model) = makeScreen(featured: [Fixtures.product(id: "3")], navigator: navigator)

        screen.loadViewIfNeeded()
        await model.load()
        await settle { screen.dataSource.snapshot().numberOfItems > 0 }
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        screen.collectionView(collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))

        #expect(navigator.events == [.product(id: "3")])
    }
}
