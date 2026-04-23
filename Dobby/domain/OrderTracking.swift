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
    let deliveryAddress: String?
    let lat: Double?
    let lng: Double?
    let createdAt: String?
    let shopName: String?
    let estimatedPreparationMinutes: Int?
    let estimatedDeliveryMinutes: Int?
    let deliveryRating: Int?
    let canRateDelivery: Bool
    let items: [OrderTrackingLineItem]
    let deliveryMan: OrderTrackingCourier?
}

struct OrderTrackingLineItem: Hashable, Sendable {
    let productName: String
    let quantity: Int
    let price: Double
}

struct OrderTrackingCourier: Hashable, Sendable {
    let id: String
    let name: String
    let celphone: String?
    let profilePhotoUrl: String?
    let lat: Double?
    let lng: Double?
}
