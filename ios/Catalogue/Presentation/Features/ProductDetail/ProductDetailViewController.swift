import UIKit

/// Product page: renders `ProductDetailViewModel.display`, with an Enquire button pinned to the bottom.
final class ProductDetailViewController: UIViewController {
    private let model: ProductDetailViewModel
    private let imageLoader: any ImageLoading

    private let productImage = ProductImageView()
    private let categoryLabel = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.textSecondary)
    private let titleLabel = UILabel(font: Theme.current.typography.sectionTitle, color: Theme.current.palette.textPrimary, lines: 0)
    private let priceLabel = UILabel(font: Theme.current.typography.priceLarge, color: Theme.current.palette.textPrimary)
    private let ratingView = RatingView()
    private let aboutLabel = UILabel(font: Theme.current.typography.sectionTitle, color: Theme.current.palette.textPrimary)
    private let descriptionLabel = UILabel(font: Theme.current.typography.body, color: Theme.current.palette.textSecondary, lines: 0)
    private var displayedImageURL: URL?

    init(model: ProductDetailViewModel, imageLoader: any ImageLoading) {
        self.model = model
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = Theme.current
        view.backgroundColor = theme.palette.background

        aboutLabel.text = model.aboutTitle
        aboutLabel.accessibilityTraits = .header

        let priceRow = UIStackView(arrangedSubviews: [priceLabel, UIView(), ratingView])
        priceRow.alignment = .center

        let content = UIStackView(arrangedSubviews: [productImage, categoryLabel, titleLabel, priceRow, aboutLabel, descriptionLabel])
        content.axis = .vertical
        content.spacing = theme.spacing.s
        content.setCustomSpacing(theme.spacing.l, after: productImage)
        content.setCustomSpacing(theme.spacing.xl, after: priceRow)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        let enquireBar = makeEnquireBar()
        enquireBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(enquireBar)
        let inset = theme.spacing.l
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: enquireBar.topAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: inset),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -inset),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -inset),
            productImage.heightAnchor.constraint(equalToConstant: 300),

            enquireBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            enquireBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            enquireBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        renderOnChange { [weak self] in self?.render() }
        Task { [model] in await model.refresh() }
    }

    private func makeEnquireBar() -> UIView {
        let theme = Theme.current
        var configuration = UIButton.Configuration.filled()
        configuration.title = model.enquireTitle
        configuration.image = UIImage(systemName: "envelope")
        configuration.imagePadding = theme.spacing.s
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.model.enquire()
        })
        button.tintColor = theme.palette.accent
        button.accessibilityHint = "Opens a form to ask our sales team about this product"
        button.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        bar.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: bar.contentView.topAnchor, constant: theme.spacing.m),
            button.leadingAnchor.constraint(equalTo: bar.contentView.safeAreaLayoutGuide.leadingAnchor, constant: theme.spacing.l),
            button.trailingAnchor.constraint(equalTo: bar.contentView.safeAreaLayoutGuide.trailingAnchor, constant: -theme.spacing.l),
            button.bottomAnchor.constraint(equalTo: bar.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -theme.spacing.s),
        ])
        return bar
    }

    private func render() {
        let display = model.display
        title = display.title
        categoryLabel.text = display.categoryName.uppercased()
        titleLabel.text = display.title
        priceLabel.text = display.priceText
        ratingView.configure(text: display.ratingText, accessibilityLabel: display.ratingAccessibilityLabel)
        descriptionLabel.text = display.description
        if displayedImageURL != display.imageURL {
            displayedImageURL = display.imageURL
            productImage.load(display.imageURL, using: imageLoader)
        }
    }
}

#Preview {
    UINavigationController(
        rootViewController: ProductDetailViewController(
            model: ProductDetailViewModel(
                product: PreviewData.products[0],
                fetchProduct: PreviewData.fetchProduct,
                navigator: nil
            ),
            imageLoader: PreviewData.imageLoader
        )
    )
}
