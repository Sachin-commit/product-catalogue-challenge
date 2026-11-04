import UIKit

/// Search results: renders `SearchViewModel` and forwards taps to it.
final class SearchResultsViewController: UIViewController, UICollectionViewDelegate {
    enum Section: Hashable, Sendable { case results }

    private let model: SearchViewModel
    private let imageLoader: any ImageLoading

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewCompositionalLayout(section: CatalogueLayout.grid())
    )
    private(set) lazy var dataSource = makeDataSource()
    private let stateView = UIContentUnavailableView(configuration: ContentStates.loading())

    init(model: SearchViewModel, imageLoader: any ImageLoading) {
        self.model = model
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = model.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = Theme.current
        view.backgroundColor = theme.palette.background
        collectionView.backgroundColor = theme.palette.background
        collectionView.delegate = self
        collectionView.contentInset.top = theme.spacing.l

        for subview in [collectionView, stateView] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.topAnchor.constraint(equalTo: view.topAnchor),
                subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        renderOnChange { [weak self] in self?.render() }
        Task { [model] in await model.loadIfNeeded() }
    }

    private func render() {
        switch model.state {
        case .idle, .loading:
            stateView.show(ContentStates.loading("Searching…"))
        case let .failed(message):
            stateView.show(ContentStates.error(title: model.errorTitle, message: message) { [weak self] in
                self?.reload()
            })
        case let .loaded(products) where products.isEmpty:
            var configuration = UIContentUnavailableConfiguration.search()
            configuration.secondaryText = model.emptyMessage
            stateView.show(configuration)
        case let .loaded(products):
            stateView.show(nil)
            var snapshot = NSDiffableDataSourceSnapshot<Section, ProductCardModel>()
            snapshot.appendSections([.results])
            snapshot.appendItems(products, toSection: .results)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func reload() {
        Task { [model] in await model.load() }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, ProductCardModel> {
        let imageLoader = self.imageLoader
        let cell = UICollectionView.CellRegistration<ProductCell, ProductCardModel> { cell, _, product in
            cell.configure(with: product, imageLoader: imageLoader)
        }
        let header = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, _ in
            guard let self else { return }
            let count = self.dataSource.snapshot().numberOfItems
            header.configure(title: model.resultsTitle, subtitle: model.resultsSummary(count: count))
        }

        let dataSource = UICollectionViewDiffableDataSource<Section, ProductCardModel>(collectionView: collectionView) {
            collectionView, indexPath, product in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: product)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        return dataSource
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let product = dataSource.itemIdentifier(for: indexPath) {
            model.selectProduct(id: product.id)
        }
    }
}
