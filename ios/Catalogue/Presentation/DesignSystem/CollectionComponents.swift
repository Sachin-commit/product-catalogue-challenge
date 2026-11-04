import UIKit

/// Title (and optional subtitle) above a collection view section.
final class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel(font: Theme.current.typography.sectionTitle, color: Theme.current.palette.textPrimary, lines: 0)
    private let subtitleLabel = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.textSecondary, lines: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.accessibilityTraits = .header
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = Theme.current.spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.current.spacing.s),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, subtitle: String? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
    }
}

/// Loading, error and empty states, shown over a screen's content.
@MainActor
enum ContentStates {
    static func loading(_ text: String? = nil) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.loading()
        if let text { configuration.text = text }
        return configuration
    }

    static func error(
        title: String,
        message: String,
        retry: @escaping @MainActor @Sendable () -> Void
    ) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = title
        configuration.secondaryText = message
        var button = UIButton.Configuration.borderedProminent()
        button.title = "Try again"
        configuration.button = button
        configuration.buttonProperties.primaryAction = UIAction { _ in retry() }
        return configuration
    }

    static func empty(title: String, message: String, systemImage: String) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: systemImage)
        configuration.text = title
        configuration.secondaryText = message
        return configuration
    }
}

extension UIContentUnavailableView {
    /// Covers the content with a loading, error or empty state; pass nil to reveal the content.
    func show(_ state: UIContentUnavailableConfiguration?) {
        isHidden = state == nil
        if let state { configuration = state }
    }
}

/// Section layouts shared by the browsing screens.
@MainActor
enum CatalogueLayout {
    /// Section header lined up with the section's tiles.
    static func header() -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        let inset = Theme.current.spacing.l
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
        return header
    }

    /// A horizontally scrolling row of product tiles.
    static func carousel() -> NSCollectionLayoutSection {
        let theme = Theme.current
        let size = NSCollectionLayoutSize(
            widthDimension: .absolute(theme.carouselTileWidth),
            heightDimension: .estimated(260)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = theme.spacing.m
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: theme.spacing.l, bottom: theme.spacing.xl, trailing: theme.spacing.l)
        section.boundarySupplementaryItems = [header()]
        // Headers use their own insets (above) rather than the section's, so they line up with the tiles.
        section.supplementaryContentInsetsReference = .none
        return section
    }

    /// A two-column grid of product tiles.
    static func grid() -> NSCollectionLayoutSection {
        let theme = Theme.current
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .estimated(260))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(260)),
            repeatingSubitem: item,
            count: 2
        )
        group.interItemSpacing = .fixed(theme.spacing.m)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = theme.spacing.m
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: theme.spacing.l, bottom: theme.spacing.xl, trailing: theme.spacing.l)
        section.boundarySupplementaryItems = [header()]
        section.supplementaryContentInsetsReference = .none
        return section
    }

    /// An inset-grouped list (used for category links).
    static func list(environment: any NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        configuration.backgroundColor = Theme.current.palette.background
        return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
    }
}
