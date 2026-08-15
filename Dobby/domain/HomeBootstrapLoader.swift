//
//  HomeBootstrapLoader.swift
//  Dobby
//

import Foundation

enum HomeBootstrapLoader {
    static func load(deps: AppDependencies) async -> HomeBootstrapSnapshot {
        async let homeTask = loadHome(deps: deps)
        async let addressesTask = loadAddresses(deps: deps)
        async let adsTask = loadAds(deps: deps)
        async let activeOrdersTask = loadActiveOrders(deps: deps)
        async let shopCoordsTask = loadShopCoords(deps: deps)
        async let pricingTask = loadDeliveryPricing(deps: deps)

        let home = await homeTask
        let addresses = await addressesTask
        let ads = await adsTask
        let activeOrders = await activeOrdersTask
        let shopLookup = await shopCoordsTask
        let pricing = await pricingTask

        return HomeBootstrapSnapshot(
            featuredPlaces: home.featuredPlaces,
            bestSellerProducts: home.bestSellerProducts,
            ads: ads.ads,
            activeOrders: activeOrders,
            addressLabel: addresses.addressLabel,
            address: addresses.address,
            addressDetails: addresses.addressDetails,
            defaultAddressId: addresses.defaultAddressId,
            deliveryLatitude: addresses.deliveryLatitude,
            deliveryLongitude: addresses.deliveryLongitude,
            addressFetchCompleted: addresses.addressFetchCompleted,
            needsDeliveryAddressCallout: addresses.needsDeliveryAddressCallout,
            warningMessage: addresses.warningMessage ?? ads.warningMessage,
            errorMessage: home.errorMessage,
            deliveryPricingSettings: pricing,
            shopCoordsByShopId: shopLookup.coordinatesByShopId,
            shopTypeByShopId: shopLookup.typeByShopId
        )
    }

    private struct HomePartial {
        var featuredPlaces: [FeaturedPlace] = []
        var bestSellerProducts: [BestSellerProduct] = []
        var errorMessage: String?
    }

    private struct AddressPartial {
        var addressLabel: String?
        var address: String?
        var addressDetails: String?
        var defaultAddressId: String?
        var deliveryLatitude: Double?
        var deliveryLongitude: Double?
        var addressFetchCompleted = false
        var needsDeliveryAddressCallout = false
        var warningMessage: String?
    }

    private struct AdsPartial {
        var ads: [Ad] = []
        var warningMessage: String?
    }

    private static func loadHome(deps: AppDependencies) async -> HomePartial {
        switch await deps.placesRepository.getHome() {
        case .success(let data):
            return HomePartial(
                featuredPlaces: data.featuredPlaces,
                bestSellerProducts: data.bestSellerProducts
            )
        case .failure(let e):
            guard !e.shouldSuppressUserMessage else { return HomePartial() }
            return HomePartial(errorMessage: userFacingMessage(for: e, http: deps.httpClient))
        }
    }

    private static func loadAddresses(deps: AppDependencies) async -> AddressPartial {
        switch await deps.userAddressRepository.getAddresses() {
        case .success(let list):
            return addressPartial(from: list)
        case .failure(let e):
            guard !e.shouldSuppressUserMessage else {
                return AddressPartial(addressFetchCompleted: true)
            }
            var partial = AddressPartial(
                addressLabel: "Casa",
                addressFetchCompleted: true,
                needsDeliveryAddressCallout: false
            )
            if case .http(let he) = e {
                partial.warningMessage = deps.httpClient.userFacingMessage(from: he)
            } else {
                partial.warningMessage = "Inicia sesión para ver tus direcciones."
            }
            return partial
        }
    }

    private static func addressPartial(from list: [UserAddress]) -> AddressPartial {
        let chosen = list.first(where: \.isDefault) ?? list.first
        let rawAddress = chosen?.address
        let details = chosen?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AddressPartial(
            addressLabel: chosen?.label ?? "Casa",
            address: rawAddress?.addressWithColonyOnly(),
            addressDetails: (details?.isEmpty == false) ? details : nil,
            defaultAddressId: chosen?.id,
            deliveryLatitude: chosen?.lat,
            deliveryLongitude: chosen?.lng,
            addressFetchCompleted: true,
            needsDeliveryAddressCallout: list.isEmpty
        )
    }

    private static func loadAds(deps: AppDependencies) async -> AdsPartial {
        switch await deps.adsRepository.getAds() {
        case .success(let list):
            return AdsPartial(ads: list)
        case .failure(let e):
            guard !e.shouldSuppressUserMessage else { return AdsPartial() }
            return AdsPartial(
                ads: [],
                warningMessage: userFacingMessage(for: e, http: deps.httpClient)
            )
        }
    }

    private static func loadActiveOrders(deps: AppDependencies) async -> [ActiveOrder] {
        switch await deps.orderRepository.getActiveOrders() {
        case .success(let orders):
            return orders
        case .failure:
            return []
        }
    }

    private static func loadShopCoords(deps: AppDependencies) async -> ShopDeliveryLookup {
        switch await deps.placesRepository.getShopDeliveryLookup() {
        case .success(let lookup):
            return lookup
        case .failure:
            return ShopDeliveryLookup(coordinatesByShopId: [:], typeByShopId: [:])
        }
    }

    private static func loadDeliveryPricing(deps: AppDependencies) async -> DeliveryPricingSettings {
        await deps.deliveryPricingConfigRepository.refresh()
        return deps.deliveryPricingConfigRepository.currentSettings()
    }

    private static func userFacingMessage(for error: HomeRepositoryError, http: DobbyHTTPClient) -> String {
        if case .http(let he) = error {
            return http.userFacingMessage(from: he)
        }
        return "No se pudo cargar el inicio."
    }
}
