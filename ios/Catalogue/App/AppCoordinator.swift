import UIKit

/// Owns the browsing flow's navigation stack and builds each screen with its
/// dependencies. Implements the navigation protocols the view models call, so
/// view models decide *when* to navigate and this decides *how*.
@MainActor
final class AppCoordinator: HomeNavigating, ProductDetailNavigating {
    let navigationController = UINavigationController()
    private let container: AppContainer
    private var enquiryFlow: EnquiryCoordinator?

    init(container: AppContainer) {
        self.container = container
        navigationController.navigationBar.prefersLargeTitles = true
    }

    func start() {
        let model = HomeViewModel(fetchHomeContent: container.fetchHomeContent, navigator: self)
        let home = HomeViewController(model: model, imageLoader: container.imageLoader)
        navigationController.setViewControllers([home], animated: false)
    }

    // MARK: - HomeNavigating

    func showCategory(_ category: ProductCategory) {
        let model = CategoryViewModel(category: category, fetchListing: container.fetchCategoryListing, navigator: self)
        push(CategoryViewController(model: model, imageLoader: container.imageLoader))
    }

    func showSearchResults(for query: SearchQuery) {
        let model = SearchViewModel(query: query, searchProducts: container.searchProducts, navigator: self)
        push(SearchResultsViewController(model: model, imageLoader: container.imageLoader))
    }

    func showProduct(_ product: Product) {
        let model = ProductDetailViewModel(product: product, fetchProduct: container.fetchProduct, navigator: self)
        push(ProductDetailViewController(model: model, imageLoader: container.imageLoader))
    }

    // MARK: - ProductDetailNavigating

    func showEnquiry(for product: Product) {
        let flow = EnquiryCoordinator(container: container) { [weak self] in
            self?.enquiryFlow = nil
        }
        enquiryFlow = flow
        navigationController.present(flow.start(product: product), animated: true)
    }

    private func push(_ viewController: UIViewController) {
        navigationController.pushViewController(viewController, animated: true)
    }
}

/// Owns the modal enquiry flow: form, then thank-you, then dismiss.
@MainActor
final class EnquiryCoordinator: NSObject, EnquiryNavigating, UIAdaptivePresentationControllerDelegate {
    private let container: AppContainer
    private let onFinish: @MainActor @Sendable () -> Void
    private let navigationController = UINavigationController()

    init(container: AppContainer, onFinish: @escaping @MainActor @Sendable () -> Void) {
        self.container = container
        self.onFinish = onFinish
        super.init()
    }

    func start(product: Product) -> UIViewController {
        let model = EnquiryViewModel(product: product, submitEnquiry: container.submitEnquiry, navigator: self)
        navigationController.setViewControllers(
            [EnquiryViewController(model: model, imageLoader: container.imageLoader)],
            animated: false
        )
        // Also finish when the customer swipes the sheet away.
        navigationController.presentationController?.delegate = self
        return navigationController
    }

    // MARK: - EnquiryNavigating

    func showEnquiryConfirmation(_ confirmation: EnquiryConfirmation) {
        let model = EnquiryConfirmationViewModel(confirmation: confirmation, navigator: self)
        navigationController.setViewControllers([EnquiryConfirmationViewController(model: model)], animated: true)
    }

    func closeEnquiry() {
        navigationController.dismiss(animated: true)
        onFinish()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onFinish()
    }
}
