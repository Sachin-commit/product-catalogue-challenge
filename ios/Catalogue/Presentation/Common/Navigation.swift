import Foundation

// What each screen can ask to happen next. View models depend on these small
// protocols (interface segregation); the coordinators implement them
// (dependency inversion). View models hold them weakly, because the
// coordinator owns the screens that own the view models.

@MainActor
protocol ProductNavigating: AnyObject {
    func showProduct(_ product: Product)
}

@MainActor
protocol HomeNavigating: ProductNavigating {
    func showCategory(_ category: ProductCategory)
    func showSearchResults(for query: SearchQuery)
}

@MainActor
protocol ProductDetailNavigating: AnyObject {
    func showEnquiry(for product: Product)
}

@MainActor
protocol EnquiryNavigating: AnyObject {
    func showEnquiryConfirmation(_ confirmation: EnquiryConfirmation)
    func closeEnquiry()
}

/// What the thank-you screen needs to know about the enquiry that was sent.
struct EnquiryConfirmation: Equatable, Sendable {
    let productTitle: String
    let email: String
    let reference: String
}
