import Foundation
import Testing
@testable import Catalogue

@MainActor
struct EnquiryViewModelTests {
    private let product = Fixtures.product(id: "3", title: "Mens Cotton Jacket")

    private func makeModel(
        navigator: NavigatorSpy = NavigatorSpy(),
        _ handler: @escaping @Sendable (EnquiryDraft) async throws -> EnquiryReceipt
    ) -> EnquiryViewModel {
        EnquiryViewModel(
            product: product,
            submitEnquiry: DefaultSubmitEnquiryUseCase(repository: StubEnquiryRepository(handler: handler)),
            navigator: navigator
        )
    }

    private func fillValidForm(_ model: EnquiryViewModel) {
        model.name = "  Jane Doe "
        model.email = "jane@example.com "
        model.phone = ""
        model.message = "Do you have XL?"
    }

    @Test func submitsTheCleanedUpEnquiryAndShowsTheThankYouScreen() async {
        let sent = Recorder<EnquiryDraft>()
        let navigator = NavigatorSpy()
        let model = makeModel(navigator: navigator) { draft in
            await sent.record(draft)
            return EnquiryReceipt(reference: "ENQ-42")
        }
        fillValidForm(model)

        await model.submit()

        #expect(model.phase == .submitted(reference: "ENQ-42"))
        #expect(await sent.values == [
            EnquiryDraft(productId: "3", name: "Jane Doe", email: "jane@example.com", message: "Do you have XL?"),
        ])
        #expect(navigator.events == [
            .confirmation(EnquiryConfirmation(productTitle: "Mens Cotton Jacket", email: "jane@example.com", reference: "ENQ-42")),
        ])
    }

    @Test func blocksSubmissionAndExplainsEachInvalidField() async {
        let sent = Recorder<EnquiryDraft>()
        let navigator = NavigatorSpy()
        let model = makeModel(navigator: navigator) { draft in
            await sent.record(draft)
            return EnquiryReceipt(reference: "unused")
        }
        model.name = "   "
        model.email = "jane@"
        model.phone = "call me"

        await model.submit()

        #expect(model.phase == .editing)
        #expect(model.fieldErrors == [
            .name: "Enter your name",
            .email: "Enter a valid email address",
            .phone: "Enter a valid phone number",
        ])
        #expect(await sent.values.isEmpty)
        #expect(navigator.events.isEmpty)
    }

    @Test func showsServerFieldErrorsNextToTheFields() async {
        let model = makeModel { _ in
            throw CatalogueError.invalidEnquiry([.email: .rejected(message: "That address bounced")])
        }
        fillValidForm(model)

        await model.submit()

        #expect(model.phase == .editing)
        #expect(model.fieldErrors == [.email: "That address bounced"])
        #expect(model.submitError == nil)
    }

    @Test func showsARetryableErrorWhenSendingFailsAndKeepsWhatWasTyped() async {
        let model = makeModel { _ in throw CatalogueError.serviceUnavailable }
        fillValidForm(model)

        await model.submit()

        #expect(model.phase == .editing)
        #expect(model.submitError == "We couldn't send your enquiry. Please try again.")
        #expect(model.message == "Do you have XL?")
    }

    @Test func ignoresASecondTapWhileSending() async {
        let sent = Recorder<EnquiryDraft>()
        let model = makeModel { draft in
            await sent.record(draft)
            try await Task.sleep(for: .milliseconds(50))
            return EnquiryReceipt(reference: "ENQ-1")
        }
        fillValidForm(model)

        async let first: Void = model.submit()
        async let second: Void = model.submit()
        _ = await (first, second)

        #expect(await sent.values.count == 1)
        #expect(model.phase == .submitted(reference: "ENQ-1"))
    }

    @Test func editingAFieldClearsOnlyThatFieldsError() async {
        let model = makeModel { _ in EnquiryReceipt(reference: "x") }
        await model.submit()
        #expect(model.fieldErrors[.name] != nil)
        #expect(model.fieldErrors[.email] != nil)

        model.clearError(for: .name)

        #expect(model.fieldErrors[.name] == nil)
        #expect(model.fieldErrors[.email] != nil)
    }

    @Test func protectsAHalfWrittenEnquiryFromAnAccidentalSwipe() {
        let model = makeModel { _ in EnquiryReceipt(reference: "x") }
        #expect(model.allowsInteractiveDismissal)
        model.message = "Hello"
        #expect(model.allowsInteractiveDismissal == false)
    }

    @Test func cancellingClosesTheForm() {
        let navigator = NavigatorSpy()
        let model = makeModel(navigator: navigator) { _ in EnquiryReceipt(reference: "x") }

        model.cancel()

        #expect(navigator.events == [.closeEnquiry])
    }

    @Test func thankYouScreenTextAndDone() {
        let navigator = NavigatorSpy()
        let confirmation = EnquiryConfirmationViewModel(
            confirmation: EnquiryConfirmation(productTitle: "Jacket", email: "jane@example.com", reference: "ENQ-9"),
            navigator: navigator
        )

        #expect(confirmation.heading == "Thank you")
        #expect(confirmation.message.contains("Jacket"))
        #expect(confirmation.message.contains("jane@example.com"))
        #expect(confirmation.referenceText == "Reference: ENQ-9")
        confirmation.done()
        #expect(navigator.events == [.closeEnquiry])
    }
}
