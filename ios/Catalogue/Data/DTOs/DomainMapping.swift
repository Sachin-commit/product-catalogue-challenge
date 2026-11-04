import Foundation

// DTO → Domain and transport error → domain error. The only place that knows both shapes.

extension CategoryDTO {
    func toDomain() -> ProductCategory {
        ProductCategory(slug: slug, name: name)
    }
}

extension ProductDTO {
    func toDomain() -> Product {
        Product(
            id: id,
            title: title,
            description: description,
            category: category.toDomain(),
            price: Money(amountMinor: price.amountMinor, currency: price.currency),
            imageURL: imageUrl,
            rating: rating.map { Rating(average: $0.average, count: $0.count) }
        )
    }
}

extension CategoryListingDTO {
    func toDomain() -> CategoryListing {
        CategoryListing(
            category: category.toDomain(),
            topRated: topRated.map { $0.toDomain() },
            more: more.map { $0.toDomain() }
        )
    }
}

extension EnquiryRequestDTO {
    init(_ draft: EnquiryDraft) {
        self.init(
            productId: draft.productId,
            name: draft.name,
            email: draft.email,
            phone: draft.phone,
            message: draft.message
        )
    }
}

extension APIError {
    /// Translates what went wrong on the wire into what it means for the app.
    func toDomain() -> CatalogueError {
        switch self {
        case .cannotReachServer:
            return .unreachable
        case let .server(status, _, _, fieldErrors):
            switch status {
            case 404:
                return .notFound
            case 429:
                return .tooManyRequests
            case 400 where !fieldErrors.isEmpty:
                return Self.enquiryIssues(from: fieldErrors).map(CatalogueError.invalidEnquiry) ?? .unexpected
            case 500...:
                return .serviceUnavailable
            default:
                return .unexpected
            }
        case let .unexpectedStatus(status):
            return status >= 500 ? .serviceUnavailable : .unexpected
        case .invalidResponse:
            return .unexpected
        }
    }

    /// Field errors about form fields become validation issues; anything else
    /// (e.g. an invalid product id) is not something the customer can fix.
    private static func enquiryIssues(from fieldErrors: [FieldError]) -> [EnquiryField: ValidationIssue]? {
        var issues: [EnquiryField: ValidationIssue] = [:]
        for error in fieldErrors {
            guard let field = EnquiryField(rawValue: error.field) else { return nil }
            issues[field] = .rejected(message: error.message)
        }
        return issues
    }
}
