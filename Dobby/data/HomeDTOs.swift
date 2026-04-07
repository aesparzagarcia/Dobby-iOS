//
//  HomeDTOs.swift
//  Dobby
//

import Foundation

struct HomeResponseDTO: Decodable {
    let featuredPlaces: [FeaturedPlaceDTO]
    let bestSellerProducts: [BestSellerProductDTO]
}

struct FeaturedPlaceDTO: Decodable {
    let id: String
    let name: String
    let logoUrl: String?
    let type: String?
    let category: String?
    let kind: String
    let rate: Float
}

struct ShopProductDTO: Decodable {
    let id: String
    let name: String
    let description: String?
    let price: Double
    let imageUrl: String?
    let rate: Float
    let hasPromotion: Bool
    let discount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, price, imageUrl, rate, discount
        case hasPromotion = "has_promotion"
    }
}

struct BestSellerProductDTO: Decodable {
    let id: String
    let name: String
    let imageUrl: String?
    let price: Double
    let rate: Float
    let hasPromotion: Bool
    let discount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, imageUrl, price, rate, discount
        case hasPromotion = "has_promotion"
    }
}

struct ProductDetailDTO: Decodable {
    let id: String
    let name: String
    let description: String?
    let price: Double
    let imageUrls: [String]?
    let rate: Float
    let hasPromotion: Bool
    let discount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, price, imageUrls, rate, discount
        case hasPromotion = "has_promotion"
    }
}

struct AdDTO: Decodable {
    let id: String
    let imageUrl: String?
    let advertiserName: String
    let description: String?
    let address: String?
    let contactPhone: String?
    let whatsapp: String?
    let email: String?
    let facebookUrl: String?
    let instagramUrl: String?
}

struct CreateAddressRequest: Encodable {
    let label: String
    let description: String?
    let address: String
    let lat: Double
    let lng: Double
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case label, description, address, lat, lng
        case isDefault = "is_default"
    }
}

struct AddressDTO: Decodable {
    let id: String
    let label: String
    let description: String?
    let address: String
    let lat: Double
    let lng: Double
    let isDefault: Bool
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, description, address, lat, lng
        case isDefault = "is_default"
        case isActive = "is_active"
    }
}
