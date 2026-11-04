import UIKit

/// Design tokens. The brand is still being designed, so every colour, font,
/// spacing and size the screens use comes from here. Re-skinning the app means
/// setting a different `Theme.current` at launch, not editing screens.
struct Theme {
    struct Palette {
        var accent: UIColor
        var onAccent: UIColor
        var background: UIColor
        var surface: UIColor
        var imageBackground: UIColor
        var textPrimary: UIColor
        var textSecondary: UIColor
        var rating: UIColor
        var success: UIColor
        var error: UIColor
    }

    struct Typography {
        var screenTitle: UIFont
        var sectionTitle: UIFont
        var productTitle: UIFont
        var body: UIFont
        var caption: UIFont
        var price: UIFont
        var priceLarge: UIFont
        var button: UIFont
    }

    struct Spacing: Sendable {
        var xs: CGFloat = 4
        var s: CGFloat = 8
        var m: CGFloat = 12
        var l: CGFloat = 16
        var xl: CGFloat = 24
        var xxl: CGFloat = 32
    }

    struct Radius: Sendable {
        var s: CGFloat = 8
        var m: CGFloat = 12
        var l: CGFloat = 20
    }

    var brandName: String
    var palette: Palette
    var typography: Typography
    var spacing = Spacing()
    var radius = Radius()
    /// Width of a product tile in horizontal carousels.
    var carouselTileWidth: CGFloat = 168
    /// Height of the image area on a product tile.
    var tileImageHeight: CGFloat = 140
}

extension Theme {
    /// The theme every screen reads. Set it before the first screen is created.
    @MainActor static var current = Theme.standard

    /// Placeholder brand until the creative work lands. System semantic colours
    /// keep light and dark mode correct; text styles keep Dynamic Type working.
    @MainActor static let standard = Theme(
        brandName: "Catalogue",
        palette: Palette(
            accent: UIColor(red: 0.13, green: 0.36, blue: 0.85, alpha: 1),
            onAccent: .white,
            background: .systemGroupedBackground,
            surface: .secondarySystemGroupedBackground,
            // Product photos have white backgrounds, so keep them on white in dark mode too.
            imageBackground: .white,
            textPrimary: .label,
            textSecondary: .secondaryLabel,
            rating: .systemOrange,
            success: .systemGreen,
            error: .systemRed
        ),
        typography: Typography(
            screenTitle: .preferred(.largeTitle, weight: .bold),
            sectionTitle: .preferred(.title3, weight: .semibold),
            productTitle: .preferred(.subheadline, weight: .medium),
            body: .preferred(.body),
            caption: .preferred(.caption1),
            price: .preferred(.subheadline, weight: .semibold),
            priceLarge: .preferred(.title2, weight: .bold),
            button: .preferred(.headline)
        )
    )
}

extension UIFont {
    /// A Dynamic Type font for `style` with a custom weight; labels using it must set
    /// `adjustsFontForContentSizeCategory = true` to follow the user's text size.
    @MainActor
    static func preferred(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let defaultSize = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        ).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: defaultSize, weight: weight))
    }
}

extension UILabel {
    /// A label styled from the theme that scales with Dynamic Type.
    convenience init(font: UIFont, color: UIColor, lines: Int = 1) {
        self.init(frame: .zero)
        self.font = font
        textColor = color
        numberOfLines = lines
        adjustsFontForContentSizeCategory = true
    }
}
