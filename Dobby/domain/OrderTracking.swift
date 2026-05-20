//
//  OrderTracking.swift
//  Dobby
//
//  Parity with Android `OrderTracking` (map + detail sheet).
//

import Foundation

struct OrderTrackingDetail: Identifiable, Hashable, Sendable {
    let id: String
    let status: String
    var total: Double
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
    let items: [OrderTrackingLineItem]
    let deliveryMan: OrderTrackingCourier?

    var isDelivered: Bool { status.uppercased() == "DELIVERED" }

    var courierArrivedAtCustomer: Bool {
        guard let at = arrivedAtCustomerAt?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !at.isEmpty
    }

    var hasPendingRatings: Bool {
        canRateDelivery || canRateShop || items.contains(where: \.canRate)
    }
}

struct OrderTrackingLineItem: Hashable, Sendable {
    let productId: String
    let productName: String
    let quantity: Int
    let price: Double
    let rating: Int?
    let canRate: Bool
}

struct OrderTrackingCourier: Hashable, Sendable {
    let id: String
    let name: String
    let celphone: String?
    let profilePhotoUrl: String?
    let lat: Double?
    let lng: Double?
}
