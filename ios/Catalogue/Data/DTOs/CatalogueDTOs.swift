import Foundation

// Data transfer objects: the exact JSON shapes of our backend's /api/v1 contract.
// They live only in the Data layer and are mapped to Domain entities in
// `DomainMapping.swift`, so a contract change is absorbed here, not in screens.

struct CategoryDTO: Decodable {
    let slug: String
    let name: String
}

struct MoneyDTO: Decodable {
    let amountMinor: Int
    let currency: String
}

struct RatingDTO: Decodable {
    let average: Double
    let count: Int
}

struct ProductDTO: Decodable {
    let id: String
    let title: String
    let description: String
    let category: CategoryDTO
    let price: MoneyDTO
    let imageUrl: URL
    let rating: RatingDTO?
}

struct ProductListDTO: Decodable {
    let products: [ProductDTO]
}

struct CategoryListDTO: Decodable {
    let categories: [CategoryDTO]
}

struct CategoryListingDTO: Decodable {
    let category: CategoryDTO
    let topRated: [ProductDTO]
    let more: [ProductDTO]
}

struct EnquiryRequestDTO: Encodable, Equatable {
    let productId: String
    let name: String
    let email: String
    /// Optional fields are left out of the JSON when nil.
    let phone: String?
    let message: String?
}

struct EnquiryReceiptDTO: Decodable {
    let reference: String
}
