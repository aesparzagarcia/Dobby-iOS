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
    /// SHOP | SERVICE_PAYMENT
    let orderType: String
    /// RESTAURANT | SHOP | CAR_WASH | …
    let shopType: String?
    var total: Double
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
    let items: [OrderTrackingLineItem]
    let deliveryMan: OrderTrackingCourier?

    var isServicePayment: Bool { orderType.uppercased() == "SERVICE_PAYMENT" }

    var isCarWash: Bool {
        shopType?.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("CAR_WASH") == .orderedSame
    }

    var isDelivered: Bool { status.uppercased() == "DELIVERED" }

    var courierArrivedAtCustomer: Bool {
        guard let at = arrivedAtCustomerAt?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !at.isEmpty
    }

    var hasPendingRatings: Bool {
        canRateDelivery || canRateShop || items.contains(where: \.canRate)
    }

    var isAssignedToCourier: Bool { status.uppercased() == "ASSIGNED" }

    var isOnDelivery: Bool { status.uppercased() == "ON_DELIVERY" }

    /// Shop while ASSIGNED; customer address when ON_DELIVERY / DELIVERED.
    var routeDestinationCoordinate: (lat: Double, lng: Double)? {
        switch status.uppercased() {
        case "ASSIGNED":
            return shopCoordinate
        case "ON_DELIVERY", "DELIVERED":
            return customerCoordinate
        default:
            return nil
        }
    }

    /// After the shop confirmed: show restaurant + delivery address (before courier is assigned).
    var showsRestaurantAndCustomerOnMap: Bool {
        Self.preCourierBothMarkerStatuses.contains(status.uppercased())
    }

    var shopCoordinate: (lat: Double, lng: Double)? {
        guard let shopLat, let shopLng else { return nil }
        return (shopLat, shopLng)
    }

    var customerCoordinate: (lat: Double, lng: Double)? {
        guard let lat, let lng else { return nil }
        return (lat, lng)
    }

    /// Points for fitting the map camera.
    var mapCameraFitCoordinates: [(lat: Double, lng: Double)] {
        var points: [(lat: Double, lng: Double)] = []
        if showsRestaurantAndCustomerOnMap {
            if let shopCoordinate, Self.isValidMapCoordinate(shopCoordinate) {
                points.append(shopCoordinate)
            }
            if let customerCoordinate, Self.isValidMapCoordinate(customerCoordinate) {
                points.append(customerCoordinate)
            }
        } else if let routeDestinationCoordinate, Self.isValidMapCoordinate(routeDestinationCoordinate) {
            points.append(routeDestinationCoordinate)
        } else if status.uppercased() == "PENDING",
                  let customerCoordinate,
                  Self.isValidMapCoordinate(customerCoordinate) {
            points.append(customerCoordinate)
        }
        if let dm = deliveryMan, let lat = dm.lat, let lng = dm.lng,
           Self.isValidMapCoordinate((lat, lng)) {
            points.append((lat, lng))
        }
        return points
    }

    /// Pending orders: show delivery address before shop/courier markers appear.
    var showsPendingCustomerOnMap: Bool {
        status.uppercased() == "PENDING" && customerCoordinate != nil
    }

    private static func isValidMapCoordinate(_ coordinate: (lat: Double, lng: Double)) -> Bool {
        let lat = coordinate.lat
        let lng = coordinate.lng
        guard lat >= -90, lat <= 90, lng >= -180, lng <= 180 else { return false }
        guard abs(lat) > 1e-4 || abs(lng) > 1e-4 else { return false }
        return true
    }

    private static let preCourierBothMarkerStatuses: Set<String> = [
        "CONFIRMED", "PREPARING", "READY_FOR_PICKUP",
    ]
}

struct OrderTrackingLineItem: Identifiable, Hashable, Sendable {
    /// Unique per line in the order (not just productId — duplicates / empty ids break ForEach).
    let id: String
    let productId: String
    let productName: String
    let quantity: Int
    let price: Double
    let imageUrl: String?
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
