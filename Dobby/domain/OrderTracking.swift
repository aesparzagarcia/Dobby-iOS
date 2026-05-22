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
    let shopAddress: String?
    let shopLat: Double?
    let shopLng: Double?
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
            if let shopCoordinate { points.append(shopCoordinate) }
            if let customerCoordinate { points.append(customerCoordinate) }
        } else if let routeDestinationCoordinate {
            points.append(routeDestinationCoordinate)
        }
        if let dm = deliveryMan, let lat = dm.lat, let lng = dm.lng {
            points.append((lat, lng))
        }
        return points
    }

    private static let preCourierBothMarkerStatuses: Set<String> = [
        "CONFIRMED", "PREPARING", "READY_FOR_PICKUP",
    ]
}

struct OrderTrackingLineItem: Hashable, Sendable {
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
