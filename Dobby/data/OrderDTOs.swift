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

struct CreateServicePaymentItemRequestDTO: Encodable, Sendable {
    let serviceId: String
    let serviceNumber: String
    let amount: Double
}

struct CreateOrderRequestDTO: Encodable, Sendable {
    let addressId: String
    let items: [CreateOrderItemRequestDTO]
    let serviceItems: [CreateServicePaymentItemRequestDTO]?
    let orderType: String?
    let deliveryFee: Double

    enum CodingKeys: String, CodingKey {
        case addressId
        case items
        case serviceItems
        case orderType
        case deliveryFee
    }

    init(
        addressId: String,
        items: [CreateOrderItemRequestDTO] = [],
        serviceItems: [CreateServicePaymentItemRequestDTO]? = nil,
        orderType: String? = nil,
        deliveryFee: Double
    ) {
        self.addressId = addressId
        self.items = items
        self.serviceItems = serviceItems
        self.orderType = orderType
        self.deliveryFee = deliveryFee
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

struct OrderHistoryDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let createdAt: String?
    let shopName: String?
    let items: [ActiveOrderItemDTO]?

    enum CodingKeys: String, CodingKey {
        case id, status, total, items
        case createdAt = "created_at"
        case shopName = "shop_name"
    }
}

struct ActiveOrderDTO: Decodable, Sendable {
    let id: String
    let status: String
    let total: Double
    let deliveryAddress: String?
    let createdAt: String?
    let shopType: String?
    let items: [ActiveOrderItemDTO]?

    enum CodingKeys: String, CodingKey {
        case id, status, total, items
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
        case shopType = "shop_type"
    }
}

// MARK: - Order tracking (map + detail sheet)

struct OrderTrackingDTO: Decodable, Sendable {
    let id: String
    let status: String
    let orderType: String?
    let shopType: String?
    let total: Double
    let serviceFee: Double
    let deliveryFee: Double
    let productsSubtotal: Double
    let deliveryAddress: String?
    let lat: Double?
    let lng: Double?
    let createdAt: String?
    let shopName: String?
    let shopAddress: String?
    let shopLat: Double?
    let shopLng: Double?
    let estimatedPreparationMinutes: Int?
    let estimatedDeliveryMinutes: Int?
    let arrivedAtCustomerAt: String?
    let deliveryCode: String?
    let deliveryRating: Int?
    let canRateDelivery: Bool
    let shopRating: Int?
    let canRateShop: Bool
    let items: [OrderTrackingItemDTO]
    let deliveryMan: OrderTrackingDeliveryManDTO?

    enum CodingKeys: String, CodingKey {
        case id, status, total, lat, lng, items
        case orderType = "order_type"
        case shopType = "shop_type"
        case serviceFee = "service_fee"
        case deliveryFee = "delivery_fee"
        case productsSubtotal = "products_subtotal"
        case deliveryAddress = "delivery_address"
        case createdAt = "created_at"
        case shopName = "shop_name"
        case shopAddress = "shop_address"
        case shopLat = "shop_lat"
        case shopLng = "shop_lng"
        case estimatedPreparationMinutes = "estimated_preparation_minutes"
        case estimatedDeliveryMinutes = "estimated_delivery_minutes"
        case arrivedAtCustomerAt = "arrived_at_customer_at"
        case deliveryCode = "delivery_code"
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
        orderType = try c.decodeIfPresent(String.self, forKey: .orderType)
        shopType = try c.decodeIfPresent(String.self, forKey: .shopType)
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        serviceFee = try c.decodeIfPresent(Double.self, forKey: .serviceFee) ?? 0
        deliveryFee = try c.decodeIfPresent(Double.self, forKey: .deliveryFee) ?? 0
        productsSubtotal = try c.decodeIfPresent(Double.self, forKey: .productsSubtotal) ?? 0
        deliveryAddress = try c.decodeIfPresent(String.self, forKey: .deliveryAddress)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        shopName = try c.decodeIfPresent(String.self, forKey: .shopName)
        shopAddress = try c.decodeIfPresent(String.self, forKey: .shopAddress)
        shopLat = try c.decodeIfPresent(Double.self, forKey: .shopLat)
        shopLng = try c.decodeIfPresent(Double.self, forKey: .shopLng)
        estimatedPreparationMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedPreparationMinutes)
        estimatedDeliveryMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedDeliveryMinutes)
        arrivedAtCustomerAt = try c.decodeIfPresent(String.self, forKey: .arrivedAtCustomerAt)
        deliveryCode = try c.decodeIfPresent(String.self, forKey: .deliveryCode)
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
    let imageUrl: String?
    let rating: Int?
    let canRate: Bool

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productIdCamel = "productId"
        case productName = "product_name"
        case quantity, price, rating
        case imageUrl = "image_url"
        case canRate = "can_rate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let snake = (try c.decodeIfPresent(String.self, forKey: .productId))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let camel = (try c.decodeIfPresent(String.self, forKey: .productIdCamel))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        productId = !snake.isEmpty ? snake : camel
        productName = try c.decode(String.self, forKey: .productName)
        quantity = try c.decode(Int.self, forKey: .quantity)
        price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
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
