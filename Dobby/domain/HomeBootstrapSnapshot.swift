//
//  HomeBootstrapSnapshot.swift
//  Dobby
//

import Foundation

struct HomeBootstrapSnapshot {
    var featuredPlaces: [FeaturedPlace] = []
    var bestSellerProducts: [BestSellerProduct] = []
    var ads: [Ad] = []
    var activeOrders: [ActiveOrder] = []
    var addressLabel: String?
    var address: String?
    var addressDetails: String?
    var defaultAddressId: String?
    var deliveryLatitude: Double?
    var deliveryLongitude: Double?
    var addressFetchCompleted = false
    var needsDeliveryAddressCallout = false
    var warningMessage: String?
    var errorMessage: String?
    var deliveryPricingSettings: DeliveryPricingSettings = .default
    var shopCoordsByShopId: [String: (Double, Double)] = [:]
    var shopTypeByShopId: [String: String] = [:]
}
