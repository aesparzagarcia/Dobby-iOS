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
    func getShopProducts(shopId: String) async -> Result<[ShopProduct], HomeRepositoryError>
    /// Parity with Android `PlacesRepository.getProduct` → `GET app/products/:id`.
    func getProduct(id: String) async -> Result<ProductDetail, HomeRepositoryError>
}

protocol AdsRepository: Sendable {
    func getAds() async -> Result<[Ad], HomeRepositoryError>
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
        rate: p.rate
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
        discount: p.discount
    )
}

private func mapShopProduct(_ p: ShopProductDTO) -> ShopProduct {
    ShopProduct(
        id: p.id,
        name: p.name,
        description: p.description,
        price: p.price,
        imageUrl: AppConfiguration.fullImageURL(p.imageUrl),
        rate: p.rate,
        hasPromotion: p.hasPromotion,
        discount: p.discount
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
        hasPromotion: dto.hasPromotion,
        discount: dto.discount
    )
}

final class PlacesRepositoryImpl: PlacesRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func getHome() async -> Result<HomeData, HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let result: Result<HomeResponseDTO, HTTPClientError> = await api.get("app/home", bearerToken: token)
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
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let result: Result<[BestSellerProductDTO], HTTPClientError> = await api.get("app/promotions", bearerToken: token)
        switch result {
        case .success(let list):
            return .success(list.map(mapBestSeller))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getShopProducts(shopId: String) async -> Result<[ShopProduct], HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let path = "app/shops/\(shopId)/products"
        let result: Result<[ShopProductDTO], HTTPClientError> = await api.get(path, bearerToken: token)
        switch result {
        case .success(let list):
            return .success(list.map(mapShopProduct))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getProduct(id: String) async -> Result<ProductDetail, HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let path = "app/products/\(id)"
        let result: Result<ProductDetailDTO, HTTPClientError> = await api.get(path, bearerToken: token)
        switch result {
        case .success(let dto):
            return .success(mapProductDetail(dto))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }
}

final class AdsRepositoryImpl: AdsRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func getAds() async -> Result<[Ad], HomeRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let result: Result<[AdDTO], HTTPClientError> = await api.get("app/ads", bearerToken: token)
        switch result {
        case .success(let list):
            let ads = list.map { dto in
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
                    instagramUrl: dto.instagramUrl
                )
            }
            return .success(ads)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
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
            AuthSessionNavigation.notifyIfMissingAccessToken()
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
            AuthSessionNavigation.notifyIfMissingAccessToken()
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
            AuthSessionNavigation.notifyIfMissingAccessToken()
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
}
