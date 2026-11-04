import UIKit

/// A product photo on a white rounded card. Gets its image from an injected `ImageLoading`.
final class ProductImageView: UIView {
    private let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?

    init() {
        super.init(frame: .zero)
        let theme = Theme.current
        backgroundColor = theme.palette.imageBackground
        layer.cornerRadius = theme.radius.m
        clipsToBounds = true
        isAccessibilityElement = false

        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = theme.palette.textSecondary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        let inset = theme.spacing.m
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func load(_ url: URL, using loader: any ImageLoading) {
        loadTask?.cancel()
        imageView.image = nil
        loadTask = Task { [weak self] in
            let image = await loader.image(for: url)
            guard !Task.isCancelled else { return }
            self?.imageView.image = image ?? UIImage(systemName: "photo")
        }
    }

    func cancel() {
        loadTask?.cancel()
        imageView.image = nil
    }
}

/// "★ 4.7 (500)". Shows already-formatted text; hides itself when there is none.
final class RatingView: UIStackView {
    private let star = UIImageView(image: UIImage(systemName: "star.fill"))
    private let label = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.textPrimary)

    init() {
        super.init(frame: .zero)
        axis = .horizontal
        spacing = Theme.current.spacing.xs
        alignment = .center
        star.tintColor = Theme.current.palette.rating
        star.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        star.setContentHuggingPriority(.required, for: .horizontal)
        addArrangedSubview(star)
        addArrangedSubview(label)
        isAccessibilityElement = true
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(text: String?, accessibilityLabel: String?) {
        isHidden = text == nil
        label.text = text
        self.accessibilityLabel = accessibilityLabel
    }
}

/// The product card used in grids and carousels. Renders a `ProductCardModel`; no formatting here.
final class ProductCell: UICollectionViewCell {
    private let productImage = ProductImageView()
    private let titleLabel = UILabel(font: Theme.current.typography.productTitle, color: Theme.current.palette.textPrimary, lines: 2)
    private let priceLabel = UILabel(font: Theme.current.typography.price, color: Theme.current.palette.textPrimary)
    private let ratingView = RatingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let theme = Theme.current
        contentView.backgroundColor = theme.palette.surface
        contentView.layer.cornerRadius = theme.radius.l
        contentView.clipsToBounds = true

        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, UIView(), ratingView])
        priceRow.alignment = .center
        priceRow.spacing = theme.spacing.xs

        // Two lines are always reserved for the title so tiles in a row line up.
        let twoLines = ceil(titleLabel.font.lineHeight * 2)
        titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: twoLines).isActive = true

        let stack = UIStackView(arrangedSubviews: [productImage, titleLabel, priceRow])
        stack.axis = .vertical
        stack.spacing = theme.spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        let inset = theme.spacing.s
        NSLayoutConstraint.activate([
            productImage.heightAnchor.constraint(equalToConstant: theme.tileImageHeight),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -inset),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Shows product details"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with model: ProductCardModel, imageLoader: any ImageLoading) {
        titleLabel.text = model.title
        priceLabel.text = model.priceText
        ratingView.configure(text: model.ratingText, accessibilityLabel: model.ratingAccessibilityLabel)
        productImage.load(model.imageURL, using: imageLoader)
        accessibilityLabel = model.accessibilityLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        productImage.cancel()
    }
}
