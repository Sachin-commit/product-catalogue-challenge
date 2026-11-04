import Foundation

/// Turns domain values into display text. Kept out of the Domain layer
/// (formatting is a presentation concern) and out of views (so it is testable).
struct ProductFormatter: Sendable {
    var locale: Locale = .current

    /// e.g. "$109.95" for en_US.
    func price(_ money: Money) -> String {
        (Decimal(money.amountMinor) / 100).formatted(.currency(code: money.currency).locale(locale))
    }

    /// e.g. "4.7 (500)".
    func ratingText(_ rating: Rating) -> String {
        "\(average(rating)) (\(rating.count))"
    }

    func ratingAccessibilityLabel(_ rating: Rating) -> String {
        "Rated \(average(rating)) out of 5 from \(rating.count) reviews"
    }

    private func average(_ rating: Rating) -> String {
        rating.average.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}

/// Everything a product tile shows, already formatted. Cells render this and nothing else.
struct ProductCardModel: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let priceText: String
    let ratingText: String?
    let ratingAccessibilityLabel: String?
    let imageURL: URL

    var accessibilityLabel: String {
        [title, priceText, ratingAccessibilityLabel].compactMap { $0 }.joined(separator: ", ")
    }

    init(_ product: Product, formatter: ProductFormatter = ProductFormatter()) {
        id = product.id
        title = product.title
        priceText = formatter.price(product.price)
        ratingText = product.rating.map(formatter.ratingText)
        ratingAccessibilityLabel = product.rating.map(formatter.ratingAccessibilityLabel)
        imageURL = product.imageURL
    }
}

/// Everything the product page shows, already formatted.
struct ProductDetailModel: Equatable, Sendable {
    let title: String
    let categoryName: String
    let priceText: String
    let ratingText: String?
    let ratingAccessibilityLabel: String?
    let description: String
    let imageURL: URL

    init(_ product: Product, formatter: ProductFormatter = ProductFormatter()) {
        title = product.title
        categoryName = product.category.name
        priceText = formatter.price(product.price)
        ratingText = product.rating.map(formatter.ratingText)
        ratingAccessibilityLabel = product.rating.map(formatter.ratingAccessibilityLabel)
        description = product.description
        imageURL = product.imageURL
    }
}
