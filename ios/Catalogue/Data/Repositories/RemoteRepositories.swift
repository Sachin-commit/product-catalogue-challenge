import Foundation

/// Reads the catalogue from our backend's /api/v1. Never from Fake Store directly.
struct RemoteCatalogueRepository: CatalogueRepository {
    private let http: HTTPClient

    init(http: HTTPClient) {
        self.http = http
    }

    func featuredProducts() async throws -> [Product] {
        try await translatingErrors {
            let response: ProductListDTO = try await http.get("api/v1/featured")
            return response.products.map { $0.toDomain() }
        }
    }

    func categories() async throws -> [ProductCategory] {
        try await translatingErrors {
            let response: CategoryListDTO = try await http.get("api/v1/categories")
            return response.categories.map { $0.toDomain() }
        }
    }

    func categoryListing(slug: String) async throws -> CategoryListing {
        try await translatingErrors {
            let response: CategoryListingDTO = try await http.get("api/v1/categories/\(slug)/products")
            return response.toDomain()
        }
    }

    func searchProducts(matching query: SearchQuery) async throws -> [Product] {
        try await translatingErrors {
            let response: ProductListDTO = try await http.get(
                "api/v1/products",
                query: [URLQueryItem(name: "search", value: query.text)]
            )
            return response.products.map { $0.toDomain() }
        }
    }

    func product(id: String) async throws -> Product {
        try await translatingErrors {
            let response: ProductDTO = try await http.get("api/v1/products/\(id)")
            return response.toDomain()
        }
    }
}

/// Sends enquiries to our backend, which emails the sales inbox.
struct RemoteEnquiryRepository: EnquiryRepository {
    private let http: HTTPClient

    init(http: HTTPClient) {
        self.http = http
    }

    func submit(_ enquiry: EnquiryDraft) async throws -> EnquiryReceipt {
        try await translatingErrors {
            let response: EnquiryReceiptDTO = try await http.post("api/v1/enquiries", body: EnquiryRequestDTO(enquiry))
            return EnquiryReceipt(reference: response.reference)
        }
    }
}

/// Keeps transport errors inside the Data layer: callers only ever see
/// `CatalogueError` (or `CancellationError`, which passes through untouched).
private func translatingErrors<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as APIError {
        throw error.toDomain()
    }
}
