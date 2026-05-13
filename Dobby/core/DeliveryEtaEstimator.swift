//
//  DeliveryEtaEstimator.swift
//  Dobby
//
//  ETA aproximada tienda → domicilio (Haversine + prep + factor vial). Paridad con Android.
//

import Foundation

enum DeliveryEtaEstimator {
    private static let roadFactor = 1.32
    private static let avgSpeedKmh = 24.0
    private static let prepMinutes = 14.0
    /// Solo si faltan coordenadas de domicilio o de tienda en líneas del carrito; con datos se muestra el rango calculado.
    private static let fallbackLabel = "30–45 min"

    static func estimateLabel(
        userLatitude: Double?,
        userLongitude: Double?,
        cartLines: [CartLineItem],
        shopCoordsByShopId: [String: (Double, Double)]
    ) -> String {
        guard let uLat = userLatitude, let uLng = userLongitude,
              uLat.isFinite, uLng.isFinite
        else { return fallbackLabel }

        var seen = Set<String>()
        var maxCenter = 0.0
        var any = false
        for line in cartLines {
            let pair: (Double, Double)? = {
                if let a = line.pickupLatitude, let b = line.pickupLongitude,
                   a.isFinite, b.isFinite { return (a, b) }
                if let sid = line.shopId, let p = shopCoordsByShopId[sid] { return p }
                return nil
            }()
            guard let (sLat, sLng) = pair else { continue }
            let key = "\(sLat),\(sLng)"
            guard seen.insert(key).inserted else { continue }
            let c = centerMinutes(userLat: uLat, userLng: uLng, shopLat: sLat, shopLng: sLng)
            maxCenter = max(maxCenter, c)
            any = true
        }
        guard any else { return fallbackLabel }

        let low = Int((maxCenter * 0.82).rounded()).clamped(to: 18...150)
        var high = Int((maxCenter * 1.18).rounded()).clamped(to: low + 5...160)
        if high <= low { high = low + 8 }
        return "\(low)\u{2013}\(high) min"
    }

    private static func centerMinutes(userLat: Double, userLng: Double, shopLat: Double, shopLng: Double) -> Double {
        let m = haversineMeters(lat1: userLat, lon1: userLng, lat2: shopLat, lon2: shopLng)
        let roadKm = (m / 1000.0) * roadFactor
        let travelMin = (roadKm / avgSpeedKmh) * 60.0
        return min(max(prepMinutes + travelMin, 22), 130)
    }

    private static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r1 = lat1 * .pi / 180
        let r2 = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(r1) * cos(r2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - min(1, max(0, h))))
        return 6_371_000 * c
    }
}

private extension BinaryInteger {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
