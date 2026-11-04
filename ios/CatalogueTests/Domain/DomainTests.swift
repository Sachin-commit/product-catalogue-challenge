import Foundation
import Testing
@testable import Catalogue

struct SearchQueryTests {
    @Test func trimsWhitespace() {
        #expect(SearchQuery("  jacket \n")?.text == "jacket")
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func rejectsInputWithNothingToSearchFor(input: String) {
        #expect(SearchQuery(input) == nil)
    }

    @Test func capsLengthAtTheBackendLimit() {
        #expect(SearchQuery(String(repeating: "a", count: 150))?.text.count == SearchQuery.maxLength)
    }
}

struct EnquiryDraftTests {
    @Test func trimsTextAndTreatsBlankOptionalFieldsAsAbsent() {
        let draft = EnquiryDraft(productId: "3", name: "  Jane Doe ", email: " jane@example.com ", phone: "  ", message: "")
        #expect(draft.name == "Jane Doe")
        #expect(draft.email == "jane@example.com")
        #expect(draft.phone == nil)
        #expect(draft.message == nil)
    }
}

struct EnquiryValidatorTests {
    private let validator = EnquiryValidator()
    private func draft(name: String = "Jane", email: String = "jane@example.com", phone: String = "", message: String = "") -> EnquiryDraft {
        EnquiryDraft(productId: "3", name: name, email: email, phone: phone, message: message)
    }

    @Test func acceptsTheMinimum() {
        #expect(validator.validate(draft()).isEmpty)
    }

    @Test func reportsEveryInvalidField() {
        let issues = validator.validate(draft(name: " ", email: "jane@", phone: "call me", message: String(repeating: "x", count: 2001)))
        #expect(issues == [
            .name: .missing,
            .email: .invalidFormat,
            .phone: .invalidFormat,
            .message: .tooLong(max: 2000),
        ])
    }

    @Test func requiresAnEmail() {
        #expect(validator.validate(draft(email: "")) == [.email: .missing])
    }

    @Test func limitsNameLength() {
        #expect(validator.validate(draft(name: String(repeating: "a", count: 101))) == [.name: .tooLong(max: 100)])
    }

    @Test(arguments: ["+65 9123 4567", "(555) 010-0000", ""])
    func acceptsReasonablePhoneNumbersOrNone(phone: String) {
        #expect(validator.validate(draft(phone: phone)).isEmpty)
    }
}

struct SubmitEnquiryUseCaseTests {
    @Test func validatesBeforeSendingAndSendsNothingWhenInvalid() async {
        let sent = Recorder<EnquiryDraft>()
        let useCase = DefaultSubmitEnquiryUseCase(repository: StubEnquiryRepository { draft in
            await sent.record(draft)
            return EnquiryReceipt(reference: "unused")
        })

        await #expect(throws: CatalogueError.invalidEnquiry([.name: .missing])) {
            try await useCase.execute(EnquiryDraft(productId: "3", name: "", email: "jane@example.com"))
        }
        #expect(await sent.values.isEmpty)
    }

    @Test func sendsAValidDraftAndReturnsTheReceipt() async throws {
        let useCase = DefaultSubmitEnquiryUseCase(repository: StubEnquiryRepository { _ in EnquiryReceipt(reference: "ENQ-1") })
        let receipt = try await useCase.execute(EnquiryDraft(productId: "3", name: "Jane", email: "jane@example.com"))
        #expect(receipt == EnquiryReceipt(reference: "ENQ-1"))
    }
}

struct FetchHomeContentUseCaseTests {
    @Test func combinesFeaturedProductsAndCategories() async throws {
        var repository = StubCatalogueRepository()
        repository.featured = { [Fixtures.product(id: "1")] }
        repository.categoryList = { [Fixtures.jackets] }

        let content = try await DefaultFetchHomeContentUseCase(repository: repository).execute()

        #expect(content == HomeContent(featured: [Fixtures.product(id: "1")], categories: [Fixtures.jackets]))
    }

    @Test func failsAsAWholeIfEitherPartFails() async {
        var repository = StubCatalogueRepository()
        repository.featured = { [Fixtures.product(id: "1")] }
        repository.categoryList = { throw CatalogueError.serviceUnavailable }

        await #expect(throws: CatalogueError.serviceUnavailable) {
            try await DefaultFetchHomeContentUseCase(repository: repository).execute()
        }
    }
}
