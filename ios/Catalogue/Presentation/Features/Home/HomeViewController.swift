import UIKit

/// Home: search bar, the owner's featured products, and links to each category.
/// A passive view: renders `HomeViewModel` and forwards user actions to it.
final class HomeViewController: UIViewController, UICollectionViewDelegate {
    enum Section: Hashable, Sendable { case featured, categories }
    enum Item: Hashable, Sendable {
        case product(ProductCardModel)
        case category(ProductCategory)
    }

    private let model: HomeViewModel
    private let imageLoader: any ImageLoading

    private let searchBar = SearchBarView()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private(set) lazy var dataSource = makeDataSource()
    private let stateView = UIContentUnavailableView(configuration: ContentStates.loading())

    init(model: HomeViewModel, imageLoader: any ImageLoading) {
        self.model = model
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = Theme.current.brandName
        navigationItem.largeTitleDisplayMode = .always
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = Theme.current
        view.backgroundColor = theme.palette.background

        searchBar.onTextChange = { [weak self] text in self?.model.searchText = text }
        searchBar.onSearch = { [weak self] in self?.model.search() }

        collectionView.backgroundColor = theme.palette.background
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.pullToRefresh()
        })

        for subview in [searchBar, collectionView, stateView] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: theme.spacing.s),
            searchBar.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: theme.spacing.l),
            searchBar.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -theme.spacing.l),
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: theme.spacing.l),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
        ])
        setContentScrollView(collectionView)

        renderOnChange { [weak self] in self?.render() }
        Task { [model] in await model.loadIfNeeded() }
    }

    // MARK: - Rendering

    private func render() {
        searchBar.setSearchEnabled(model.canSearch)

        switch model.state {
        case .idle, .loading:
            stateView.show(ContentStates.loading("Loading products…"))
        case let .failed(message):
            stateView.show(ContentStates.error(title: model.errorTitle, message: message) { [weak self] in
                self?.reload()
            })
        case let .loaded(content):
            stateView.show(nil)
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([.featured, .categories])
            snapshot.appendItems(content.featured.map(Item.product), toSection: .featured)
            snapshot.appendItems(content.categories.map(Item.category), toSection: .categories)
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

    // MARK: - Collection view

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let section = self?.dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
            switch section {
            case .featured: return CatalogueLayout.carousel()
            case .categories: return CatalogueLayout.list(environment: environment)
            }
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let imageLoader = self.imageLoader
        let productCell = UICollectionView.CellRegistration<ProductCell, ProductCardModel> { cell, _, product in
            cell.configure(with: product, imageLoader: imageLoader)
        }
        let categoryCell = UICollectionView.CellRegistration<UICollectionViewListCell, ProductCategory> { cell, _, category in
            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = Theme.current.typography.body
            content.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        let header = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let self else { return }
            switch self.dataSource.sectionIdentifier(for: indexPath.section) {
            case .featured?: header.configure(title: model.featuredTitle, subtitle: model.featuredSubtitle)
            case .categories?: header.configure(title: model.categoriesTitle)
            case nil: break
            }
        }

        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            collectionView, indexPath, item in
            switch item {
            case let .product(product):
                return collectionView.dequeueConfiguredReusableCell(using: productCell, for: indexPath, item: product)
            case let .category(category):
                return collectionView.dequeueConfiguredReusableCell(using: categoryCell, for: indexPath, item: category)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        return dataSource
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case let .product(product): model.selectProduct(id: product.id)
        case let .category(category): model.selectCategory(category)
        }
    }
}

#Preview {
    UINavigationController(
        rootViewController: HomeViewController(
            model: HomeViewModel(fetchHomeContent: PreviewData.fetchHomeContent, navigator: nil),
            imageLoader: PreviewData.imageLoader
        )
    )
}
