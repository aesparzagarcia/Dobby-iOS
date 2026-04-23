//
//  OrderDTOs.swift
//  Dobby
//
//  Parity with Android `OrderDtos.kt` / `CreateOrderRequest`.
//

import Foundation

struct CreateOrderItemRequestDTO: Encodable, Sendable {
    let productId: String
    let quantity: Int
    let price: Double
}

struct CreateOrderRequestDTO: Encodable, Sendable {
    let addressId: String
    let items: [CreateOrderItemRequestDTO]
}

struct CreateOrderResponseDTO: Decodable, Sendable {
    let id: String
    let total: Double
    let status: String
    let deliveryAddress: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, total, status
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
    }
}

struct ActiveOrderDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let deliveryAddress: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, total
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
    }
}

// MARK: - Order tracking (map + detail sheet)

struct OrderTrackingDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let deliveryAddress: String?
    let lat: Double?
    let lng: Double?
    let createdAt: String?
    let shopName: String?
    let estimatedPreparationMinutes: Int?
    let estimatedDeliveryMinutes: Int?
    let deliveryRating: Int?
    let canRateDelivery: Bool
    let items: [OrderTrackingItemDTO]
    let deliveryMan: OrderTrackingDeliveryManDTO?

    enum CodingKeys: String, CodingKey {
        case id, status, total, lat, lng, items
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
        case shopName = "shop_name"
        case estimatedPreparationMinutes = "estimated_preparation_minutes"
        case estimatedDeliveryMinutes = "estimated_delivery_minutes"
        case deliveryRating = "delivery_rating"
        case canRateDelivery = "can_rate_delivery"
        case deliveryMan = "delivery_man"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(String.self, forKey: .status)
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        deliveryAddress = try c.decodeIfPresent(String.self, forKey: .deliveryAddress)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        shopName = try c.decodeIfPresent(String.self, forKey: .shopName)
        estimatedPreparationMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedPreparationMinutes)
        estimatedDeliveryMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedDeliveryMinutes)
        deliveryRating = try c.decodeIfPresent(Int.self, forKey: .deliveryRating)
        canRateDelivery = try c.decodeIfPresent(Bool.self, forKey: .canRateDelivery) ?? false
        items = try c.decodeIfPresent([OrderTrackingItemDTO].self, forKey: .items) ?? []
        deliveryMan = try c.decodeIfPresent(OrderTrackingDeliveryManDTO.self, forKey: .deliveryMan)
    }
}

struct OrderTrackingItemDTO: Decodable, Sendable {
    let productName: String
    let quantity: Int
    let price: Double

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case quantity, price
    }
}

struct OrderTrackingDeliveryManDTO: Decodable, Sendable {
    let id: String
    let name: String
    let celphone: String?
    let profilePhotoUrl: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, celphone, lat, lng
        case profilePhotoUrl = "profile_photo_url"
    }
}

struct RateDeliveryRequestDTO: Encodable, Sendable {
    let stars: Int
}

struct RateDeliveryResponseDTO: Decodable, Sendable {
    let ok: Bool?
}
