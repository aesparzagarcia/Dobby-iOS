//
//  DeliveryPricing.swift
//  Dobby
//
//  Paridad con Android `core/pricing` + `GET app/delivery-pricing-config`.
//

import Foundation

private let serviceFeeRate = 0.08

struct DeliveryPricingSettings: Equatable, Sendable {
    var baseFee: Double
    var pricePerKm: Double
    var weatherFee: Double
    var defaultDemandMultiplier: Double
    var defaultIsRaining: Bool
    var zoneAMaxKm: Double
    var zoneBMaxKm: Double
    var zoneCMaxKm: Double
    var zoneBFee: Double
    var zoneCFee: Double
    var zoneDFee: Double

    static let `default` = DeliveryPricingSettings(
        baseFee: 25,
        pricePerKm: 7,
        weatherFee: 15,
        defaultDemandMultiplier: 1,
        defaultIsRaining: false,
        zoneAMaxKm: 3,
        zoneBMaxKm: 7,
        zoneCMaxKm: 12,
        zoneBFee: 10,
        zoneCFee: 25,
        zoneDFee: 50
    )
}

struct DeliveryPricingInput: Sendable {
    var distanceKm: Double
    var demandMultiplier: Double
    var isRaining: Bool

    init(
        distanceKm: Double,
        demandMultiplier: Double = DeliveryPricingSettings.default.defaultDemandMultiplier,
        isRaining: Bool = DeliveryPricingSettings.default.defaultIsRaining
    ) {
        self.distanceKm = distanceKm
        self.demandMultiplier = demandMultiplier
        self.isRaining = isRaining
    }
}

struct DeliveryPricingBreakdown: Equatable, Sendable {
    var distanceKm: Double
    var baseFee: Double
    var distanceFee: Double
    var zoneFee: Double
    var weatherFee: Double
    var deliverySubtotal: Double
    var dynamicMultiplier: Double
    var finalDeliveryFee: Double
}

struct OrderPricing: Equatable, Sendable {
    var productsSubtotal: Double
    var delivery: DeliveryPricingBreakdown

    var serviceFee: Double {
        roundMoney(productsSubtotal * serviceFeeRate)
    }

    var grandTotal: Double {
        roundMoney(productsSubtotal + serviceFee + delivery.finalDeliveryFee)
    }
}

func roundMoney(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

enum DeliveryPricingCalculator {
    static func zoneFee(distanceKm: Double, config: DeliveryPricingSettings) -> Double {
        if distanceKm <= config.zoneAMaxKm { return 0 }
        if distanceKm <= config.zoneBMaxKm { return config.zoneBFee }
        if distanceKm <= config.zoneCMaxKm { return config.zoneCFee }
        return config.zoneDFee
    }

    static func calculate(
        _ input: DeliveryPricingInput,
        config: DeliveryPricingSettings = .default
    ) -> DeliveryPricingBreakdown {
        let distanceKm = max(0, input.distanceKm)
        let baseFee = config.baseFee
        let distanceFee = roundMoney(distanceKm * config.pricePerKm)
        let zone = roundMoney(zoneFee(distanceKm: distanceKm, config: config))
        let weather = input.isRaining ? config.weatherFee : 0
        let subtotal = roundMoney(baseFee + distanceFee + zone + weather)
        let multiplier = max(1, input.demandMultiplier)
        let finalFee = roundMoney(subtotal * multiplier)
        return DeliveryPricingBreakdown(
            distanceKm: roundMoney(distanceKm),
            baseFee: baseFee,
            distanceFee: distanceFee,
            zoneFee: zone,
            weatherFee: weather,
            deliverySubtotal: subtotal,
            dynamicMultiplier: multiplier,
            finalDeliveryFee: finalFee
        )
    }

    /// Envío sin costo (p. ej. CAR_WASH con repartidor propio).
    static func waived(distanceKm: Double = 0) -> DeliveryPricingBreakdown {
        DeliveryPricingBreakdown(
            distanceKm: roundMoney(max(0, distanceKm)),
            baseFee: 0,
            distanceFee: 0,
            zoneFee: 0,
            weatherFee: 0,
            deliverySubtotal: 0,
            dynamicMultiplier: 1,
            finalDeliveryFee: 0
        )
    }
}

enum GeoDistance {
    static let earthRadiusM = 6_371_000.0
    static let roadFactor = 1.32
    /// Local delivery sanity cap (road km, after `roadFactor`).
    static let maxReasonableDeliveryRoadKm = 100.0

    static func isUsableWgs84Point(lat: Double, lng: Double) -> Bool {
        guard lat.isFinite, lng.isFinite else { return false }
        guard abs(lat) <= 90, abs(lng) <= 180 else { return false }
        guard abs(lat) >= 1e-5 || abs(lng) >= 1e-5 else { return false }
        return true
    }

    static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r1 = lat1 * .pi / 180
        let r2 = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(r1) * cos(r2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
        return earthRadiusM * c
    }

    static func roadDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        haversineMeters(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2) / 1000 * roadFactor
    }

    /// Máxima distancia vial (km) domicilio ↔ pickups del carrito; `nil` si faltan coords.
    static func maxRoadKmFromPickups(
        userLat: Double?,
        userLng: Double?,
        cartLines: [CartLineItem],
        shopCoordsByShopId: [String: (Double, Double)]
    ) -> Double? {
        guard let userLat, let userLng, isUsableWgs84Point(lat: userLat, lng: userLng) else { return nil }
        let pickups = resolvePickups(cartLines: cartLines, shopCoordsByShopId: shopCoordsByShopId)
        guard !pickups.isEmpty else { return nil }
        guard let maxKm = pickups
            .map({ roadDistanceKm(lat1: userLat, lon1: userLng, lat2: $0.0, lon2: $0.1) })
            .max(),
            maxKm <= maxReasonableDeliveryRoadKm else { return nil }
        return maxKm
    }

    static func resolvePickups(
        cartLines: [CartLineItem],
        shopCoordsByShopId: [String: (Double, Double)]
    ) -> [(Double, Double)] {
        var seen = Set<String>()
        var out: [(Double, Double)] = []
        for line in cartLines {
            let pair: (Double, Double)? = {
                if let la = line.pickupLatitude, let lo = line.pickupLongitude,
                   isUsableWgs84Point(lat: la, lng: lo) { return (la, lo) }
                if let sid = line.shopId, let p = shopCoordsByShopId[sid],
                   isUsableWgs84Point(lat: p.0, lng: p.1) { return p }
                return nil
            }()
            guard let pair else { continue }
            let key = "\(pair.0),\(pair.1)"
            guard seen.insert(key).inserted else { continue }
            out.append(pair)
        }
        return out
    }
}
