import Foundation
import Testing
@testable import Catalogue

/// Exercises the real repositories and HTTP client against canned responses.
/// The transport is injected per test, so there is no shared global stub and
/// tests run in parallel.
struct RemoteRepositoryTests {
    private static let baseURL = URL(string: "http://localhost:8080")!

    private static func http(status: Int = 200, json: String, capture: Recorder<URLRequest>? = nil) -> HTTPClient {
        HTTPClient(baseURL: baseURL) { request in
            await capture?.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
    }

    private static func catalogue(status: Int = 200, json: String, capture: Recorder<URLRequest>? = nil) -> RemoteCatalogueRepository {
        RemoteCatalogueRepository(http: http(status: status, json: json, capture: capture))
    }

    private static let productJSON = """
    {
      "id": "3",
      "title": "Mens Cotton Jacket",
      "description": "Great outerwear",
      "category": { "slug": "mens-clothing", "name": "Men's Clothing" },
      "price": { "amountMinor": 5599, "currency": "USD" },
      "imageUrl": "http://localhost:8080/api/v1/products/3/image",
      "rating": { "average": 4.7, "count": 500 }
    }
    """

    // MARK: - Mapping the contract to domain entities

    @Test func mapsFeaturedProductsIntoDomainEntities() async throws {
        let recorder = Recorder<URLRequest>()
        let repository = Self.catalogue(json: #"{ "products": [\#(Self.productJSON)] }"#, capture: recorder)

        let products = try await repository.featuredProducts()

        #expect(products == [Product(
            id: "3",
            title: "Mens Cotton Jacket",
            description: "Great outerwear",
            category: ProductCategory(slug: "mens-clothing", name: "Men's Clothing"),
            price: Money(amountMinor: 5599, currency: "USD"),
            imageURL: URL(string: "http://localhost:8080/api/v1/products/3/image")!,
            rating: Rating(average: 4.7, count: 500)
        )])
        let request = try #require(await recorder.values.first)
        #expect(request.url?.absoluteString == "http://localhost:8080/api/v1/featured")
        #expect(request.httpMethod == "GET")
    }

    @Test func mapsAProductWithoutARating() async throws {
        let unrated = Self.productJSON.replacingOccurrences(
            of: #""rating": { "average": 4.7, "count": 500 }"#,
            with: #""rating": null"#
        )
        let product = try await Self.catalogue(json: unrated).product(id: "3")
        #expect(product.rating == nil)
    }

    @Test func requestsTheCategoryListingBySlug() async throws {
        let recorder = Recorder<URLRequest>()
        let json = #"{ "category": { "slug": "electronics", "name": "Electronics" }, "topRated": [], "more": [] }"#

        let listing = try await Self.catalogue(json: json, capture: recorder).categoryListing(slug: "electronics")

        #expect(listing == CategoryListing(category: ProductCategory(slug: "electronics", name: "Electronics"), topRated: [], more: []))
        #expect(await recorder.values.first?.url?.path() == "/api/v1/categories/electronics/products")
    }

    @Test func encodesSearchTermsSoTheServerReadsThemExactly() async throws {
        let recorder = Recorder<URLRequest>()
        let repository = Self.catalogue(json: #"{ "query": "x", "products": [] }"#, capture: recorder)

        _ = try await repository.searchProducts(matching: try #require(SearchQuery("men's c++ & more")))

        let url = try #require(await recorder.values.first?.url)
        #expect(url.path() == "/api/v1/products")
        // "+" must be escaped, otherwise the server decodes it as a space.
        #expect(url.query(percentEncoded: true) == "search=men's%20c%2B%2B%20%26%20more")
    }

    @Test func postsEnquiriesAsJSONAndOmitsAbsentOptionalFields() async throws {
        let recorder = Recorder<URLRequest>()
        let repository = RemoteEnquiryRepository(http: Self.http(status: 202, json: #"{ "reference": "ENQ-1" }"#, capture: recorder))

        let receipt = try await repository.submit(EnquiryDraft(productId: "3", name: "Jane", email: "jane@example.com", message: "Hi"))

        #expect(receipt == EnquiryReceipt(reference: "ENQ-1"))
        let request = try #require(await recorder.values.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: String]
        #expect(body == ["productId": "3", "name": "Jane", "email": "jane@example.com", "message": "Hi"])
    }

    // MARK: - Translating transport errors into domain errors

    @Test func turnsServerFieldErrorsIntoValidationIssues() async {
        let json = """
        { "error": { "code": "INVALID_REQUEST", "message": "The request contains invalid fields",
          "details": [ { "field": "email", "message": "Enter a valid email address" } ] } }
        """
        let repository = RemoteEnquiryRepository(http: Self.http(status: 400, json: json))

        await #expect(throws: CatalogueError.invalidEnquiry([.email: .rejected(message: "Enter a valid email address")])) {
            try await repository.submit(EnquiryDraft(productId: "3", name: "J", email: "x@y.z"))
        }
    }

    @Test(arguments: [
        (404, CatalogueError.notFound),
        (429, CatalogueError.tooManyRequests),
        (502, CatalogueError.serviceUnavailable),
        (400, CatalogueError.unexpected),
    ])
    func translatesStatusCodes(status: Int, expected: CatalogueError) async {
        let json = #"{ "error": { "code": "X", "message": "Server says no" } }"#
        await #expect(throws: expected) { try await Self.catalogue(status: status, json: json).categories() }
    }

    @Test func treatsANonJSONErrorPageByStatus() async {
        await #expect(throws: CatalogueError.serviceUnavailable) {
            try await Self.catalogue(status: 503, json: "<html>Service Unavailable</html>").categories()
        }
    }

    @Test func treatsAContractMismatchAsUnexpected() async {
        await #expect(throws: CatalogueError.unexpected) {
            try await Self.catalogue(json: #"{ "unexpected": true }"#).featuredProducts()
        }
    }

    @Test(arguments: [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut])
    func treatsConnectivityFailuresAsUnreachable(code: Int) async {
        let http = HTTPClient(baseURL: Self.baseURL) { _ in throw URLError(URLError.Code(rawValue: code)) }
        await #expect(throws: CatalogueError.unreachable) { try await RemoteCatalogueRepository(http: http).categories() }
    }

    @Test func passesCancellationThroughUntranslated() async {
        let http = HTTPClient(baseURL: Self.baseURL) { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) { try await RemoteCatalogueRepository(http: http).categories() }
    }
}
