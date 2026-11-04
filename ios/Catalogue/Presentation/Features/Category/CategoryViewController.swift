import UIKit

/// Category page: renders `CategoryViewModel` and forwards taps to it.
final class CategoryViewController: UIViewController, UICollectionViewDelegate {
    enum Section: Hashable, Sendable { case topRated, more }

    private let model: CategoryViewModel
    private let imageLoader: any ImageLoading

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private(set) lazy var dataSource = makeDataSource()
    private let stateView = UIContentUnavailableView(configuration: ContentStates.loading())

    init(model: CategoryViewModel, imageLoader: any ImageLoading) {
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
        collectionView.refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.pullToRefresh()
        })

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
            stateView.show(ContentStates.loading())
        case let .failed(message):
            stateView.show(ContentStates.error(title: model.errorTitle, message: message) { [weak self] in
                self?.reload()
            })
        case let .loaded(content) where content.isEmpty:
            stateView.show(ContentStates.empty(title: model.emptyTitle, message: model.emptyMessage, systemImage: "shippingbox"))
        case let .loaded(content):
            stateView.show(nil)
            var snapshot = NSDiffableDataSourceSnapshot<Section, ProductCardModel>()
            snapshot.appendSections([.topRated])
            snapshot.appendItems(content.topRated, toSection: .topRated)
            if !content.more.isEmpty {
                snapshot.appendSections([.more])
                snapshot.appendItems(content.more, toSection: .more)
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func reload() {
        Task { [model] in await model.load() }
    }

    private func pullToRefresh() {
        Task { [weak self] in
            await self?.model.load()
            self?.collectionView.refreshControl?.endRefreshing()
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let section = self?.dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
            switch section {
            case .topRated: return CatalogueLayout.carousel()
            case .more: return CatalogueLayout.grid()
            }
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, ProductCardModel> {
        let imageLoader = self.imageLoader
        let cell = UICollectionView.CellRegistration<ProductCell, ProductCardModel> { cell, _, product in
            cell.configure(with: product, imageLoader: imageLoader)
        }
        let header = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let self else { return }
            switch self.dataSource.sectionIdentifier(for: indexPath.section) {
            case .topRated?: header.configure(title: model.topRatedTitle)
            case .more?: header.configure(title: model.moreTitle)
            case nil: break
            }
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
