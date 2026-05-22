//
//  OrderRepositories.swift
//  Dobby
//
//  Parity with Android `OrderRepository` / `OrderRepositoryImpl`.
//

import Foundation

enum OrderRepositoryError: Error, Sendable {
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

protocol OrderRepository: Sendable {
    func createOrder(addressId: String, items: [CartLineItem], deliveryFee: Double) async -> Result<Void, OrderRepositoryError>
    func getActiveOrders() async -> Result<[ActiveOrder], OrderRepositoryError>
    func getOrderTracking(orderId: String) async -> Result<OrderTrackingDetail?, OrderRepositoryError>
    func rateDelivery(orderId: String, stars: Int) async -> Result<Void, OrderRepositoryError>
    func rateShop(orderId: String, stars: Int) async -> Result<Void, OrderRepositoryError>
    func rateProduct(orderId: String, productId: String, stars: Int) async -> Result<Void, OrderRepositoryError>
}

final class OrderRepositoryImpl: OrderRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func createOrder(addressId: String, items: [CartLineItem], deliveryFee: Double) async -> Result<Void, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let bodyItems = items.map {
            CreateOrderItemRequestDTO(productId: $0.productId, quantity: $0.quantity, price: $0.unitPrice)
        }
        let body = CreateOrderRequestDTO(addressId: addressId, items: bodyItems, deliveryFee: deliveryFee)
        let result: Result<CreateOrderResponseDTO, HTTPClientError> = await api.post("orders", body: body, bearerToken: token)
        switch result {
        case .success:
            return .success(())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getActiveOrders() async -> Result<[ActiveOrder], OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .success([])
        }
        let result: Result<[ActiveOrderDTO], HTTPClientError> = await api.get("orders/active", bearerToken: token)
        switch result {
        case .success(let list):
            return .success(list.map(Self.mapActiveOrder))
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    private static func mapActiveOrder(_ dto: ActiveOrderDTO) -> ActiveOrder {
        ActiveOrder(
            id: dto.id,
            status: dto.status,
            total: dto.total,
            deliveryAddress: dto.deliveryAddress,
            createdAt: dto.createdAt,
            productLines: (dto.items ?? []).map {
                ActiveOrderProductLine(name: $0.productName, quantity: $0.quantity)
            }
        )
    }

    func getOrderTracking(orderId: String) async -> Result<OrderTrackingDetail?, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let encodedId = orderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? orderId
        let path = "orders/\(encodedId)/tracking"
        let result: Result<OrderTrackingDTO?, HTTPClientError> = await api.getOptionalDecodableOrNotFound(path, bearerToken: token)
        switch result {
        case .success(let dto):
            guard let dto else { return .success(nil) }
            let detail = OrderTrackingDetail(
                id: dto.id,
                status: dto.status,
                total: dto.total,
                deliveryFee: dto.deliveryFee,
                productsSubtotal: dto.productsSubtotal,
                deliveryAddress: dto.deliveryAddress,
                lat: dto.lat,
                lng: dto.lng,
                createdAt: dto.createdAt,
                shopName: dto.shopName,
                shopAddress: dto.shopAddress,
                shopLat: dto.shopLat,
                shopLng: dto.shopLng,
                estimatedPreparationMinutes: dto.estimatedPreparationMinutes,
                estimatedDeliveryMinutes: dto.estimatedDeliveryMinutes,
                arrivedAtCustomerAt: dto.arrivedAtCustomerAt,
                deliveryRating: dto.deliveryRating,
                canRateDelivery: dto.canRateDelivery,
                shopRating: dto.shopRating,
                canRateShop: dto.canRateShop,
                items: dto.items.map {
                    OrderTrackingLineItem(
                        productId: $0.productId,
                        productName: $0.productName,
                        quantity: $0.quantity,
                        price: $0.price,
                        imageUrl: AppConfiguration.fullImageURL($0.imageUrl),
                        rating: $0.rating,
                        canRate: $0.canRate
                    )
                },
                deliveryMan: dto.deliveryMan.map {
                    OrderTrackingCourier(
                        id: $0.id,
                        name: $0.name,
                        celphone: $0.celphone,
                        profilePhotoUrl: $0.profilePhotoUrl,
                        lat: $0.lat,
                        lng: $0.lng
                    )
                }
            )
            return .success(detail)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func rateDelivery(orderId: String, stars: Int) async -> Result<Void, OrderRepositoryError> {
        await postRating(path: "orders/\(orderId)/rate-delivery", body: RateDeliveryRequestDTO(stars: stars))
    }

    func rateShop(orderId: String, stars: Int) async -> Result<Void, OrderRepositoryError> {
        await postRating(path: "orders/\(orderId)/rate-shop", body: RateDeliveryRequestDTO(stars: stars))
    }

    func rateProduct(orderId: String, productId: String, stars: Int) async -> Result<Void, OrderRepositoryError> {
        let body = RateProductsRequestDTO(ratings: [RateProductEntryDTO(productId: productId, stars: stars)])
        return await postRating(path: "orders/\(orderId)/rate-products", body: body)
    }

    private func postRating<B: Encodable>(path: String, body: B) async -> Result<Void, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let result: Result<RateDeliveryResponseDTO, HTTPClientError> = await api.post(path, body: body, bearerToken: token)
        switch result {
        case .success:
            return .success(())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }
}
