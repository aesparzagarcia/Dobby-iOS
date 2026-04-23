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
    func createOrder(addressId: String, items: [CartLineItem]) async -> Result<Void, OrderRepositoryError>
    func getActiveOrder() async -> Result<ActiveOrder?, OrderRepositoryError>
    func getOrderTracking(orderId: String) async -> Result<OrderTrackingDetail?, OrderRepositoryError>
    func rateDelivery(orderId: String, stars: Int) async -> Result<Void, OrderRepositoryError>
}

final class OrderRepositoryImpl: OrderRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func createOrder(addressId: String, items: [CartLineItem]) async -> Result<Void, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let bodyItems = items.map {
            CreateOrderItemRequestDTO(productId: $0.productId, quantity: $0.quantity, price: $0.unitPrice)
        }
        let body = CreateOrderRequestDTO(addressId: addressId, items: bodyItems)
        let result: Result<CreateOrderResponseDTO, HTTPClientError> = await api.post("orders", body: body, bearerToken: token)
        switch result {
        case .success:
            return .success(())
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getActiveOrder() async -> Result<ActiveOrder?, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            return .success(nil)
        }
        let result: Result<ActiveOrderDTO?, HTTPClientError> = await api.getOptionalDecodable("orders/active", bearerToken: token)
        switch result {
        case .success(let dto):
            guard let dto else { return .success(nil) }
            let order = ActiveOrder(
                id: dto.id,
                status: dto.status,
                total: dto.total,
                deliveryAddress: dto.deliveryAddress,
                createdAt: dto.createdAt
            )
            return .success(order)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }

    func getOrderTracking(orderId: String) async -> Result<OrderTrackingDetail?, OrderRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let path = "orders/\(orderId)/tracking"
        let result: Result<OrderTrackingDTO?, HTTPClientError> = await api.getOptionalDecodableOrNotFound(path, bearerToken: token)
        switch result {
        case .success(let dto):
            guard let dto else { return .success(nil) }
            let detail = OrderTrackingDetail(
                id: dto.id,
                status: dto.status,
                total: dto.total,
                deliveryAddress: dto.deliveryAddress,
                lat: dto.lat,
                lng: dto.lng,
                createdAt: dto.createdAt,
                shopName: dto.shopName,
                estimatedPreparationMinutes: dto.estimatedPreparationMinutes,
                estimatedDeliveryMinutes: dto.estimatedDeliveryMinutes,
                deliveryRating: dto.deliveryRating,
                canRateDelivery: dto.canRateDelivery,
                items: dto.items.map {
                    OrderTrackingLineItem(productName: $0.productName, quantity: $0.quantity, price: $0.price)
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
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let body = RateDeliveryRequestDTO(stars: stars)
        let path = "orders/\(orderId)/rate-delivery"
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
