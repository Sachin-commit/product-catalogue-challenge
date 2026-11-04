import Foundation
import Observation

/// Enquiry form state and actions. Validation rules live in the Domain
/// (`EnquiryValidator`, applied by `SubmitEnquiryUseCase`); this turns their
/// outcome into messages next to the fields.
@MainActor
@Observable
final class EnquiryViewModel {
    enum Phase: Equatable {
        case editing
        case submitting
        case submitted(reference: String)
    }

    let title = "Enquire"
    let product: ProductCardModel
    var name = ""
    var email = ""
    var phone = ""
    var message = ""

    private(set) var phase: Phase = .editing
    private(set) var fieldErrors: [EnquiryField: String] = [:]
    private(set) var submitError: String?

    var isSubmitting: Bool { phase == .submitting }
    var sendButtonTitle: String { isSubmitting ? "Sending…" : "Send enquiry" }

    /// Don't let a swipe throw away a half-written enquiry or interrupt sending.
    var allowsInteractiveDismissal: Bool {
        guard phase == .editing else { return !isSubmitting }
        return name.isEmpty && email.isEmpty && phone.isEmpty && message.isEmpty
    }

    private let productID: String
    private let submitEnquiry: any SubmitEnquiryUseCase
    @ObservationIgnored private weak var navigator: (any EnquiryNavigating)?

    init(product: Product, submitEnquiry: any SubmitEnquiryUseCase, navigator: (any EnquiryNavigating)?) {
        self.product = ProductCardModel(product)
        self.productID = product.id
        self.submitEnquiry = submitEnquiry
        self.navigator = navigator
    }

    func submit() async {
        guard phase == .editing else { return } // no double submits
        submitError = nil
        fieldErrors = [:]
        let draft = EnquiryDraft(productId: productID, name: name, email: email, phone: phone, message: message)

        phase = .submitting
        do {
            let receipt = try await submitEnquiry.execute(draft)
            phase = .submitted(reference: receipt.reference)
            navigator?.showEnquiryConfirmation(
                EnquiryConfirmation(productTitle: product.title, email: draft.email, reference: receipt.reference)
            )
        } catch let CatalogueError.invalidEnquiry(issues) {
            phase = .editing
            fieldErrors = issues.reduce(into: [EnquiryField: String]()) { messages, entry in
                messages[entry.key] = ErrorMessages.field(entry.key, entry.value)
            }
        } catch {
            phase = .editing
            submitError = error.isCancellation ? nil : ErrorMessages.enquiry(error)
        }
    }

    /// The customer started fixing a field: hide its error.
    func clearError(for field: EnquiryField) {
        fieldErrors[field] = nil
    }

    func cancel() {
        navigator?.closeEnquiry()
    }
}

/// The thank-you screen's text and its one action.
@MainActor
final class EnquiryConfirmationViewModel {
    let heading = "Thank you"
    let message: String
    let referenceText: String
    let doneTitle = "Done"

    private weak var navigator: (any EnquiryNavigating)?

    init(confirmation: EnquiryConfirmation, navigator: (any EnquiryNavigating)?) {
        message = "We've sent your enquiry about \(confirmation.productTitle) to our sales team. "
            + "They'll reply to \(confirmation.email) soon."
        referenceText = "Reference: \(confirmation.reference)"
        self.navigator = navigator
    }

    func done() {
        navigator?.closeEnquiry()
    }
}
