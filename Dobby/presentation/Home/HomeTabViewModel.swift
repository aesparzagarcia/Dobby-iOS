//
//  HomeTabViewModel.swift
//  Dobby
//

import Foundation

@MainActor
@Observable
final class HomeTabViewModel {
    private let placesRepository: PlacesRepository
    private let adsRepository: AdsRepository
    private let userAddressRepository: UserAddressRepository
    private let orderRepository: OrderRepository
    private let http: DobbyHTTPClient
    private let cartLocalStore: CartLocalStore

    var featuredPlaces: [FeaturedPlace] = []
    var bestSellerProducts: [BestSellerProduct] = []
    var ads: [Ad] = []
    var searchQuery = ""
    var addressLabel: String?
    var address: String?
    /// Saved address description (Android `CartUiState.addressDetails` / `addr.description`).
    var addressDetails: String?
    /// Default delivery address id for `POST orders` (parity with Android `CartViewModel.addressId`).
    var defaultAddressId: String?
    /// Coordenadas de la dirección de entrega (para ETA en carrito).
    var deliveryLatitude: Double?
    var deliveryLongitude: Double?
    /// Active order for home tracking strip (`GET orders/active`).
    var activeOrder: ActiveOrder?
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var warningMessage: String?
    /// Set after the first successful or failed `getAddresses` in this session.
    var addressFetchCompleted = false
    /// True when API returned no saved addresses (empty list).
    var needsDeliveryAddressCallout = false
    /// Full-screen “creando tu pedido…” while checkout runs + extra animation time.
    var isCheckoutLoading = false
    /// Shown from cart when pay fails (non-suppressed errors).
    var cartPayError: String?
    /// Local cart lines (SwiftData).
    var cartLines: [CartLineItem] = []
    /// `GET app/places` — tiendas con lat/lng (para ETA por `shop_id` en líneas del carrito).
    var shopCoordsByShopId: [String: (Double, Double)] = [:]

    var cartItemCount: Int {
        cartLines.reduce(0) { $0 + $1.quantity }
    }

    var cartTotal: Double {
        cartLines.reduce(0) { $0 + $1.lineTotal }
    }

    /// Entrega estimada según distancia domicilio ↔ tienda(s) en el carrito (fallback si faltan coords).
    var estimatedDeliveryLabel: String {
        DeliveryEtaEstimator.estimateLabel(
            userLatitude: deliveryLatitude,
            userLongitude: deliveryLongitude,
            cartLines: cartLines,
            shopCoordsByShopId: shopCoordsByShopId
        )
    }

    func addProductToCart(_ product: ProductDetailRoute, quantity: Int, detail: ProductDetail? = nil) {
        guard quantity > 0 else { return }
        let validDiscount = max(0, min(100, product.discount))
        let showPromotion = product.hasPromotion && validDiscount > 0
        let unitAfterDiscount = product.unitPriceAfterDiscount
        let list = product.price
        let resolvedShopId = detail?.shopId ?? product.shopId

        if let i = cartLines.firstIndex(where: { $0.productId == product.id }) {
            cartLines[i].quantity += quantity
            if cartLines[i].pickupLatitude == nil, let p = product.pickupLatitude { cartLines[i].pickupLatitude = p }
            if cartLines[i].pickupLongitude == nil, let p = product.pickupLongitude { cartLines[i].pickupLongitude = p }
            if cartLines[i].shopId == nil, let s = resolvedShopId { cartLines[i].shopId = s }
        } else {
            cartLines.append(
                CartLineItem(
                    productId: product.id,
                    name: product.name,
                    imageUrl: product.imageUrl,
                    quantity: quantity,
                    unitPrice: unitAfterDiscount,
                    listUnitPrice: list,
                    hasPromotion: showPromotion,
                    discount: validDiscount,
                    pickupLatitude: product.pickupLatitude,
                    pickupLongitude: product.pickupLongitude,
                    shopId: resolvedShopId
                )
            )
        }
        cartLocalStore.persist(lines: cartLines)
    }

    func removeCartLine(productId: String) {
        cartLines.removeAll { $0.productId == productId }
        cartLocalStore.persist(lines: cartLines)
    }

    init(
        placesRepository: PlacesRepository,
        adsRepository: AdsRepository,
        userAddressRepository: UserAddressRepository,
        orderRepository: OrderRepository,
        http: DobbyHTTPClient,
        cartLocalStore: CartLocalStore
    ) {
        self.placesRepository = placesRepository
        self.adsRepository = adsRepository
        self.userAddressRepository = userAddressRepository
        self.orderRepository = orderRepository
        self.http = http
        self.cartLocalStore = cartLocalStore
        cartLines = cartLocalStore.loadLines()
    }

    /// After tap “Pagar”: create order (Android `placeOrder`), wait API + 5s animation, then caller should pop navigation. Returns whether navigation should pop.
    func runCheckoutFlow() async -> Bool {
        cartPayError = nil
        guard let addressId = defaultAddressId, !addressId.isEmpty else {
            cartPayError = "Selecciona una dirección de entrega en Inicio."
            return false
        }
        guard !cartLines.isEmpty else {
            cartPayError = "Tu carrito está vacío."
            return false
        }
        isCheckoutLoading = true
        switch await orderRepository.createOrder(addressId: addressId, items: cartLines) {
        case .success:
            cartLines = []
            cartLocalStore.persist(lines: [])
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            isCheckoutLoading = false
            await loadActiveOrder()
            return true
        case .failure(let e):
            isCheckoutLoading = false
            if !e.shouldSuppressUserMessage {
                cartPayError = message(for: e)
            }
            return false
        }
    }

    private func message(for error: OrderRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let he):
            return http.userFacingMessage(from: he)
        }
    }

    func loadActiveOrder() async {
        switch await orderRepository.getActiveOrder() {
        case .success(let order):
            activeOrder = order
        case .failure:
            activeOrder = nil
        }
    }

    func onSearchQueryChange(_ q: String) {
        searchQuery = q
    }

    func clearWarningMessage() {
        warningMessage = nil
    }

    func loadInitial() {
        isLoading = true
        errorMessage = nil
        warningMessage = nil
        loadAddresses()
        Task {
            await refreshShopCoords()
            switch await placesRepository.getHome() {
            case .success(let data):
                featuredPlaces = data.featuredPlaces
                bestSellerProducts = data.bestSellerProducts
                isLoading = false
            case .failure(let e):
                isLoading = false
                if !e.shouldSuppressUserMessage {
                    errorMessage = message(for: e)
                }
            }
            await loadAds()
            await loadActiveOrder()
        }
    }

    func loadHome() {
        Task {
            isLoading = true
            errorMessage = nil
            warningMessage = nil
            switch await placesRepository.getHome() {
            case .success(let data):
                featuredPlaces = data.featuredPlaces
                bestSellerProducts = data.bestSellerProducts
                isLoading = false
            case .failure(let e):
                isLoading = false
                if !e.shouldSuppressUserMessage {
                    errorMessage = message(for: e)
                }
            }
        }
    }

    func loadAddresses() {
        Task {
            switch await userAddressRepository.getAddresses() {
            case .success(let list):
                let chosen = list.first(where: \.isDefault) ?? list.first
                defaultAddressId = chosen?.id
                addressLabel = chosen?.label ?? "Casa"
                if let raw = chosen?.address {
                    address = raw.addressWithColonyOnly()
                } else {
                    address = nil
                }
                addressDetails = Self.normalizedAddressDetails(from: chosen?.description)
                deliveryLatitude = chosen?.lat
                deliveryLongitude = chosen?.lng
                addressFetchCompleted = true
                needsDeliveryAddressCallout = list.isEmpty
            case .failure(let e):
                defaultAddressId = nil
                addressLabel = "Casa"
                address = nil
                addressDetails = nil
                deliveryLatitude = nil
                deliveryLongitude = nil
                addressFetchCompleted = true
                needsDeliveryAddressCallout = false
                guard !e.shouldSuppressUserMessage else { return }
                if case .http(let he) = e {
                    warningMessage = http.userFacingMessage(from: he)
                } else {
                    warningMessage = "Inicia sesión para ver tus direcciones."
                }
            }
        }
    }

    private static func normalizedAddressDetails(from raw: String?) -> String? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private func loadAds() async {
        switch await adsRepository.getAds() {
        case .success(let list):
            ads = list
        case .failure(let e):
            ads = []
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        async let homeTask: Void = refreshHome()
        async let addrTask: Void = refreshAddresses()
        async let adsTask: Void = refreshAds()
        async let orderTask: Void = loadActiveOrder()
        async let shopCoordsTask: Void = refreshShopCoords()
        _ = await (homeTask, addrTask, adsTask, orderTask, shopCoordsTask)
        isRefreshing = false
    }

    private func refreshShopCoords() async {
        switch await placesRepository.getShopCoordinatesByShopId() {
        case .success(let m):
            shopCoordsByShopId = m
        case .failure:
            shopCoordsByShopId = [:]
        }
    }

    private func refreshHome() async {
        switch await placesRepository.getHome() {
        case .success(let data):
            featuredPlaces = data.featuredPlaces
            bestSellerProducts = data.bestSellerProducts
            errorMessage = nil
        case .failure(let e):
            if !e.shouldSuppressUserMessage {
                errorMessage = message(for: e)
            }
        }
    }

    private func refreshAddresses() async {
        switch await userAddressRepository.getAddresses() {
        case .success(let list):
            let chosen = list.first(where: \.isDefault) ?? list.first
            defaultAddressId = chosen?.id
            addressLabel = chosen?.label ?? "Casa"
            if let raw = chosen?.address {
                address = raw.addressWithColonyOnly()
            } else {
                address = nil
            }
            addressDetails = Self.normalizedAddressDetails(from: chosen?.description)
            deliveryLatitude = chosen?.lat
            deliveryLongitude = chosen?.lng
            addressFetchCompleted = true
            needsDeliveryAddressCallout = list.isEmpty
        case .failure(let e):
            defaultAddressId = nil
            addressLabel = "Casa"
            address = nil
            addressDetails = nil
            deliveryLatitude = nil
            deliveryLongitude = nil
            addressFetchCompleted = true
            needsDeliveryAddressCallout = false
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    private func refreshAds() async {
        switch await adsRepository.getAds() {
        case .success(let list):
            ads = list
        case .failure(let e):
            ads = []
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    private func message(for error: HomeRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let e):
            return http.userFacingMessage(from: e)
        }
    }
}
