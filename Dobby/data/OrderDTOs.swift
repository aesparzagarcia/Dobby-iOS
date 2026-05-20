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
    let deliveryFee: Double

    enum CodingKeys: String, CodingKey {
        case addressId
        case items
        case deliveryFee
    }
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

struct ActiveOrderItemDTO: Decodable, Sendable {
    let productName: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case quantity
    }
}

struct ActiveOrderDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let deliveryAddress: String?
    let createdAt: String?
    let items: [ActiveOrderItemDTO]?

    enum CodingKeys: String, CodingKey {
        case id, status, total, items
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
    }
}

// MARK: - Order tracking (map + detail sheet)

struct OrderTrackingDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let deliveryFee: Double
    let productsSubtotal: Double
    let deliveryAddress: String?
    let lat: Double?
    let lng: Double?
    let createdAt: String?
    let shopName: String?
    let estimatedPreparationMinutes: Int?
    let estimatedDeliveryMinutes: Int?
    let arrivedAtCustomerAt: String?
    let deliveryRating: Int?
    let canRateDelivery: Bool
    let shopRating: Int?
    let canRateShop: Bool
    let items: [OrderTrackingItemDTO]
    let deliveryMan: OrderTrackingDeliveryManDTO?

    enum CodingKeys: String, CodingKey {
        case id, status, total, lat, lng, items
        case deliveryFee = "delivery_fee"
        case productsSubtotal = "products_subtotal"
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
        case shopName = "shop_name"
        case estimatedPreparationMinutes = "estimated_preparation_minutes"
        case estimatedDeliveryMinutes = "estimated_delivery_minutes"
        case arrivedAtCustomerAt = "arrived_at_customer_at"
        case deliveryRating = "delivery_rating"
        case canRateDelivery = "can_rate_delivery"
        case shopRating = "shop_rating"
        case canRateShop = "can_rate_shop"
        case deliveryMan = "delivery_man"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(String.self, forKey: .status)
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        deliveryFee = try c.decodeIfPresent(Double.self, forKey: .deliveryFee) ?? 0
        productsSubtotal = try c.decodeIfPresent(Double.self, forKey: .productsSubtotal) ?? 0
        deliveryAddress = try c.decodeIfPresent(String.self, forKey: .deliveryAddress)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        shopName = try c.decodeIfPresent(String.self, forKey: .shopName)
        estimatedPreparationMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedPreparationMinutes)
        estimatedDeliveryMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedDeliveryMinutes)
        arrivedAtCustomerAt = try c.decodeIfPresent(String.self, forKey: .arrivedAtCustomerAt)
        deliveryRating = try c.decodeIfPresent(Int.self, forKey: .deliveryRating)
        canRateDelivery = try c.decodeIfPresent(Bool.self, forKey: .canRateDelivery) ?? false
        shopRating = try c.decodeIfPresent(Int.self, forKey: .shopRating)
        canRateShop = try c.decodeIfPresent(Bool.self, forKey: .canRateShop) ?? false
        items = try c.decodeIfPresent([OrderTrackingItemDTO].self, forKey: .items) ?? []
        deliveryMan = try c.decodeIfPresent(OrderTrackingDeliveryManDTO.self, forKey: .deliveryMan)
    }
}

struct OrderTrackingItemDTO: Decodable, Sendable {
    let productId: String
    let productName: String
    let quantity: Int
    let price: Double
    let rating: Int?
    let canRate: Bool

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productName = "product_name"
        case quantity, price, rating
        case canRate = "can_rate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productId = try c.decodeIfPresent(String.self, forKey: .productId) ?? ""
        productName = try c.decode(String.self, forKey: .productName)
        quantity = try c.decode(Int.self, forKey: .quantity)
        price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        canRate = try c.decodeIfPresent(Bool.self, forKey: .canRate) ?? false
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

struct RateProductEntryDTO: Encodable, Sendable {
    let productId: String
    let stars: Int
}

struct RateProductsRequestDTO: Encodable, Sendable {
    let ratings: [RateProductEntryDTO]
}

struct RateDeliveryResponseDTO: Decodable, Sendable {
    let ok: Bool?
}
