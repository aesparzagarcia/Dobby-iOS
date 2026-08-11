//
//  HomeRepositories.swift
//  Dobby
//

import Foundation

enum HomeRepositoryError: Error, Sendable {
    case notAuthenticated
    case http(HTTPClientError)

    var shouldSuppressUserMessage: Bool {
        switch self {
        case .notAuthenticated:
            return true
        case .http(let e):
            return AuthSessionNavigation.shouldSuppressUserMessage(for: e)
        }
    }
}

protocol PlacesRepository: Sendable {
    func getHome() async -> Result<HomeData, HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getPromotions` → `GET app/promotions`.
    func getPromotions() async -> Result<[BestSellerProduct], HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getBestSellers` → `GET app/best-sellers`.
    func getBestSellers() async -> Result<[ShopProduct], HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getFeaturedPlaces` → `GET app/featured-places`.
    func getFeaturedPlaces() async -> Result<[FeaturedPlace], HomeRepositoryError>
    func getShopProducts(shopId: String) async -> Result<ShopProductsPage, HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getProduct` → `GET app/products/:id`.
    func getProduct(id: String) async -> Result<ProductDetail, HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getService` → `GET app/services/:id`.
    func getService(id: String) async -> Result<ServiceDetail, HomeRepositoryError>
    /// Tiendas con coordenadas desde `GET app/places` (ETA por `shop_id` en carrito).
    func getShopCoordinatesByShopId() async -> Result<[String: (Double, Double)], HomeRepositoryError>
}

protocol AdsRepository: Sendable {
    func getAds() async -> Result<[Ad], HomeRepositoryError>
    /// Parity with Android `AdsRepository.getAd` → `GET app/ads/:id` (404 → `nil`).
    func getAd(id: String) async -> Result<Ad?, HomeRepositoryError>
    func recordAdClick(id: String) async
}

protocol UserAddressRepository: Sendable {
    func getAddresses() async -> Result<[UserAddress], HomeRepositoryError>
    func createAddress(
        label: String,
        description: String?,
        address: String,
        lat: Double,
        lng: Double,
        isDefault: Bool
    ) async -> Result<UserAddress, HomeRepositoryError>
    func setDefaultAddress(id: String) async -> Result<Void, HomeRepositoryError>
    func deleteAddress(id: String) async -> Result<Void, HomeRepositoryError>
}

private extension AddressDTO {
    func toUserAddress() -> UserAddress {
        UserAddress(
            id: id,
            label: label,
            description: description,
            address: address,
            lat: lat,
            lng: lng,
            isDefault: isDefault,
            isActive: isActive
        )
    }
}

private func mapFeaturedPlace(_ p: FeaturedPlaceDTO) -> FeaturedPlace {
    let isService = p.kind == "service"
    let typeLabel: String
    switch p.kind {
    case "shop":
        switch p.type {
        case "RESTAURANT": typeLabel = "Restaurante"
        case "SHOP": typeLabel = "Tienda"
        case "SERVICE_PROVIDER": typeLabel = "Servicio"
        case "CAR_WASH": typeLabel = "Autolavado"
        default: typeLabel = p.type ?? "Tienda"
        }
    case "service": typeLabel = "Servicio"
    default: typeLabel = p.type ?? p.category ?? ""
    }
    return FeaturedPlace(
        id: p.id,
        name: p.name,
        imageUrl: AppConfiguration.fullImageURL(p.logoUrl),
        typeLabel: typeLabel,
        isService: isService,
        shopType: isService ? nil : p.type,
        serviceCategory: isService ? p.category : nil,
        rate: p.rate,
        openingHour: p.openingHour,
        closingHour: p.closingHour,
        latitude: p.lat,
        longitude: p.lng
    )
}

private func mapBestSeller(_ p: BestSellerProductDTO) -> BestSellerProduct {
    BestSellerProduct(
        id: p.id,
        name: p.name,
        imageUrl: AppConfiguration.fullImageURL(p.imageUrl),
        price: p.price,
        rate: p.rate,
        hasPromotion: p.hasPromotion,
        discount: p.discount,
        shopId: CartShopSwitchPolicy.normalized(p.shopId)
    )
}

private func mapShopProduct(_ p: ShopProductDTO, fallbackShopId: String) -> ShopProduct {
    ShopProduct(
        id: p.id,
        name: p.name,
        description: p.description,
        price: p.price,
        imageUrl: AppConfiguration.fullImageURL(p.imageUrl),
        rate: p.rate,
        ratingCount: p.ratingCount ?? 0,
        hasPromotion: p.hasPromotion,
        discount: p.discount,
        shopId: CartShopSwitchPolicy.normalized(p.shopId)
            ?? CartShopSwitchPolicy.normalized(fallbackShopId),
        category: p.category
    )
}

private func mapProductDetail(_ dto: ProductDetailDTO) -> ProductDetail {
    let urls = (dto.imageUrls ?? []).map { AppConfiguration.fullImageURL($0) ?? $0 }
    return ProductDetail(
        id: dto.id,
        name: dto.name,
        description: dto.description,
        price: dto.price,
        imageUrls: urls,
        rate: dto.rate,
        ratingCount: dto.ratingCount ?? 0,
        hasPromotion: dto.hasPromotion,
        discount: dto.discount,
        shopId: CartShopSwitchPolicy.normalized(dto.shopId),
        shopType: CartShopSwitchPolicy.normalized(dto.shopType)
    )
}

private func mapServiceDetail(_ dto: ServiceDetailDTO) -> ServiceDetail {
    ServiceDetail(
        id: dto.id,
        name: dto.name,
        description: dto.description,
        imageUrl: AppConfiguration.fullImageURL(dto.logoUrl),
        category: dto.category,
        rate: dto.rate
    )
}

final class PlacesRepositoryImpl: PlacesRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    /// Public catalog endpoints: work without a session (App Store 5.1.1 guest browse).
    private var optionalBearer: String? { sessionStore.accessToken() }

    func getHome() async -> Result<HomeData, HomeRepositoryError> {
        let result: Result<HomeResponseDTO, HTTPClientError> = await api.get("app/home", bearerToken: optionalBearer)
        switch result {
        case .success(let dto):
            let places = dto.featuredPlaces.map(mapFeaturedPlace)
            let products = dto.bestSellerProducts.map(mapBestSeller)
            return .success(HomeData(featuredPlaces: places, bestSellerProducts: products))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getPromotions() async -> Result<[BestSellerProduct], HomeRepositoryError> {
        let result: Result<[BestSellerProductDTO], HTTPClientError> = await api.get("app/promotions", bearerToken: optionalBearer)
        switch result {
        case .success(let list):
            return .success(list.map(mapBestSeller))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getBestSellers() async -> Result<[ShopProduct], HomeRepositoryError> {
        let result: Result<[ShopProductDTO], HTTPClientError> = await api.get("app/best-sellers", bearerToken: optionalBearer)
        switch result {
        case .success(let list):
            return .success(list.map { mapShopProduct($0, fallbackShopId: $0.shopId ?? "") })
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getFeaturedPlaces() async -> Result<[FeaturedPlace], HomeRepositoryError> {
        let result: Result<[FeaturedPlaceDTO], HTTPClientError> = await api.get("app/featured-places", bearerToken: optionalBearer)
        switch result {
        case .success(let list):
            return .success(list.map(mapFeaturedPlace))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getShopProducts(shopId: String) async -> Result<ShopProductsPage, HomeRepositoryError> {
        let path = "app/shops/\(shopId)/products"
        let result: Result<ShopProductsResponseDTO, HTTPClientError> = await api.get(path, bearerToken: optionalBearer)
        switch result {
        case .success(let response):
            let products = response.products.map { mapShopProduct($0, fallbackShopId: shopId) }
            return .success(
                ShopProductsPage(
                    shopStatus: response.shop.status,
                    openingHour: response.shop.openingHour,
                    closingHour: response.shop.closingHour,
                    products: products,
                    shopName: response.shop.name,
                    shopType: response.shop.type,
                    logoUrl: AppConfiguration.fullImageURL(response.shop.logoUrl),
                    rate: response.shop.rate ?? 0,
                    ratingCount: response.shop.ratingCount ?? 0,
                    jobsDone: response.shop.jobsDone ?? 0
                )
            )
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getProduct(id: String) async -> Result<ProductDetail, HomeRepositoryError> {
        let path = "app/products/\(id)"
        let result: Result<ProductDetailDTO, HTTPClientError> = await api.get(path, bearerToken: optionalBearer)
        switch result {
        case .success(let dto):
            return .success(mapProductDetail(dto))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getService(id: String) async -> Result<ServiceDetail, HomeRepositoryError> {
        let path = "app/services/\(id)"
        let result: Result<ServiceDetailDTO, HTTPClientError> = await api.get(path, bearerToken: optionalBearer)
        switch result {
        case .success(let dto):
            return .success(mapServiceDetail(dto))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getShopCoordinatesByShopId() async -> Result<[String: (Double, Double)], HomeRepositoryError> {
        let token = optionalBearer
        let result: Result<PlacesResponseDTO, HTTPClientError> = await api.get("app/places", bearerToken: token)
        switch result {
        case .success(let dto):
            var coords: [String: (Double, Double)] = [:]
            for s in dto.shops {
                if let la = s.lat, let lo = s.lng, GeoDistance.isUsableWgs84Point(lat: la, lng: lo) {
                    coords[s.id] = (la, lo)
                }
            }
            return .success(coords)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }
}

private func mapAd(_ dto: AdDTO) -> Ad {
    Ad(
        id: dto.id,
        imageUrl: AppConfiguration.fullImageURL(dto.imageUrl),
        name: dto.advertiserName,
        description: dto.description,
        address: dto.address,
        contactPhone: dto.contactPhone,
        whatsapp: dto.whatsapp,
        email: dto.email,
        facebookUrl: dto.facebookUrl,
        instagramUrl: dto.instagramUrl,
        priority: min(max(dto.priority ?? 0, 0), 3)
    )
}

private struct EmptyJSON: Encodable {}

private struct TrackAdResponse: Decodable {
    let ok: Bool?
}

final class AdsRepositoryImpl: AdsRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func getAds() async -> Result<[Ad], HomeRepositoryError> {
        let result: Result<[AdDTO], HTTPClientError> = await api.get("app/ads", bearerToken: sessionStore.accessToken())
        switch result {
        case .success(let list):
            return .success(list.map(mapAd))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getAd(id: String) async -> Result<Ad?, HomeRepositoryError> {
        let path = "app/ads/\(id)"
        let result: Result<AdDTO?, HTTPClientError> = await api.getOptionalDecodableOrNotFound(path, bearerToken: sessionStore.accessToken())
        switch result {
        case .success(let dto):
            if let dto {
                return .success(mapAd(dto))
            }
            return .success(nil)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func recordAdClick(id: String) async {
        guard let token = sessionStore.accessToken() else { return }
        _ = await api.post(
            "app/ads/\(id)/click",
            body: EmptyJSON(),
            bearerToken: token
        ) as Result<TrackAdResponse, HTTPClientError>
    }
}

final class UserAddressRepositoryImpl: UserAddressRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func getAddresses() async -> Result<[UserAddress], HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .failure(.notAuthenticated)
        }
        let result: Result<[AddressDTO], HTTPClientError> = await api.get("addresses", bearerToken: token)
        switch result {
        case .success(let list):
            return .success(list.map { $0.toUserAddress() })
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func createAddress(
        label: String,
        description: String?,
        address: String,
        lat: Double,
        lng: Double,
        isDefault: Bool
    ) async -> Result<UserAddress, HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .failure(.notAuthenticated)
        }
        let body = CreateAddressRequest(
            label: label,
            description: description,
            address: address,
            lat: lat,
            lng: lng,
            isDefault: isDefault
        )
        let result: Result<AddressDTO, HTTPClientError> = await api.post("addresses", body: body, bearerToken: token)
        switch result {
        case .success(let dto):
            return .success(dto.toUserAddress())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func setDefaultAddress(id: String) async -> Result<Void, HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .failure(.notAuthenticated)
        }
        let path = "addresses/\(id)/default"
        switch await api.patch(path, bearerToken: token) {
        case .success:
            return .success(())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func deleteAddress(id: String) async -> Result<Void, HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .failure(.notAuthenticated)
        }
        let path = "addresses/\(id)"
        switch await api.delete(path: path, bearerToken: token) {
        case .success:
            return .success(())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }
}
