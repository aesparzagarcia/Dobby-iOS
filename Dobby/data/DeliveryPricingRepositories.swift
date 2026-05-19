//
//  DeliveryPricingRepositories.swift
//  Dobby
//

import Foundation

struct DeliveryPricingConfigDTO: Decodable, Sendable {
    let baseFee: Double
    let pricePerKm: Double
    let weatherFee: Double
    let defaultDemandMultiplier: Double
    let defaultIsRaining: Bool
    let zoneAMaxKm: Double
    let zoneBMaxKm: Double
    let zoneCMaxKm: Double
    let zoneBFee: Double
    let zoneCFee: Double
    let zoneDFee: Double

    func toSettings() -> DeliveryPricingSettings {
        DeliveryPricingSettings(
            baseFee: baseFee,
            pricePerKm: pricePerKm,
            weatherFee: weatherFee,
            defaultDemandMultiplier: defaultDemandMultiplier,
            defaultIsRaining: defaultIsRaining,
            zoneAMaxKm: zoneAMaxKm,
            zoneBMaxKm: zoneBMaxKm,
            zoneCMaxKm: zoneCMaxKm,
            zoneBFee: zoneBFee,
            zoneCFee: zoneCFee,
            zoneDFee: zoneDFee
        )
    }
}

protocol DeliveryPricingConfigRepository: Sendable {
    func currentSettings() -> DeliveryPricingSettings
    func refresh() async
}

final class DeliveryPricingConfigRepositoryImpl: DeliveryPricingConfigRepository, @unchecked Sendable {
    private(set) var settings: DeliveryPricingSettings = .default
    private let api: DobbyHTTPClient

    init(api: DobbyHTTPClient) {
        self.api = api
        Task { await refresh() }
    }

    func currentSettings() -> DeliveryPricingSettings {
        settings
    }

    func refresh() async {
        let result: Result<DeliveryPricingConfigDTO, HTTPClientError> = await api.get(
            "app/delivery-pricing-config",
            bearerToken: nil
        )
        if case .success(let dto) = result {
            settings = dto.toSettings()
        }
    }
}
