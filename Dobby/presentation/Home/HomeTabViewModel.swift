//
//  HomeTabViewModel.swift
//  Dobby
//

import Foundation

enum AddToCartResult: Equatable {
    case success
    case blockedCarWash
    case needsAddress
}

@MainActor
@Observable
final class HomeTabViewModel {
    private let placesRepository: PlacesRepository
    private let adsRepository: AdsRepository
    private let userAddressRepository: UserAddressRepository
    private let orderRepository: OrderRepository
    private let deliveryPricingConfigRepository: DeliveryPricingConfigRepository
    private let http: DobbyHTTPClient
    private let cartLocalStore: CartLocalStore

    private enum PendingCartAdd {
        case shopProduct(
            product: ShopProduct,
            pickupLatitude: Double?,
            pickupLongitude: Double?,
            shopId: String,
            shopType: String?
        )
        case productDetail(route: ProductDetailRoute, quantity: Int, detail: ProductDetail?)
        case servicePayment(
            service: ServiceDetail,
            serviceNumber: String,
            amount: Double
        )
    }

    private var pendingCartAdd: PendingCartAdd?

    /// Tarifas desde `GET app/delivery-pricing-config` (panel web).
    var deliveryPricingSettings: DeliveryPricingSettings = .default

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
    /// Pedidos activos (`GET orders/active`).
    var activeOrders: [ActiveOrder] = []
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

    var productsSubtotal: Double {
        roundMoney(cartLines.reduce(0) { $0 + $1.lineTotal })
    }

    /// Desglose con envío; `nil` si faltan coordenadas de entrega o de tienda.
    var orderPricing: OrderPricing? {
        let subtotal = productsSubtotal
        guard let km = GeoDistance.maxRoadKmFromPickups(
            userLat: deliveryLatitude,
            userLng: deliveryLongitude,
            cartLines: cartLines,
            shopCoordsByShopId: shopCoordsByShopId
        ) else { return nil }
        let delivery = DeliveryPricingCalculator.calculate(
            DeliveryPricingInput(
                distanceKm: km,
                demandMultiplier: deliveryPricingSettings.defaultDemandMultiplier,
                isRaining: deliveryPricingSettings.defaultIsRaining
            ),
            config: deliveryPricingSettings
        )
        return OrderPricing(productsSubtotal: subtotal, delivery: delivery)
    }

    var grandTotal: Double {
        orderPricing?.grandTotal ?? productsSubtotal
    }

    /// Dirección guardada con id y coordenadas (paridad Android `CartUiState.hasValidDeliveryAddress`).
    var hasValidDeliveryAddress: Bool {
        guard let id = defaultAddressId, !id.isEmpty else { return false }
        return deliveryLatitude != nil && deliveryLongitude != nil
    }

    /// Alias histórico (solo productos).
    var cartTotal: Double { productsSubtotal }

    /// Entrega estimada según distancia domicilio ↔ tienda(s) en el carrito (fallback si faltan coords).
    var estimatedDeliveryLabel: String {
        DeliveryEtaEstimator.estimateLabel(
            userLatitude: deliveryLatitude,
            userLongitude: deliveryLongitude,
            cartLines: cartLines,
            shopCoordsByShopId: shopCoordsByShopId
        )
    }

    /// Returns outcome so UI can show car-wash alert or open address search.
    @discardableResult
    func addProductToCart(
        _ product: ProductDetailRoute,
        quantity: Int,
        detail: ProductDetail? = nil,
        isLoggedIn: Bool = true
    ) -> AddToCartResult {
        guard quantity > 0 else { return .success }
        if isLoggedIn && !hasValidDeliveryAddress {
            pendingCartAdd = .productDetail(route: product, quantity: quantity, detail: detail)
            return .needsAddress
        }
        return performAddProductToCart(product, quantity: quantity, detail: detail)
    }

    /// Adds a SERVICE_PAYMENT line (parity with Android `CartRepository.addServiceItem`).
    @discardableResult
    func addServiceToCart(
        service: ServiceDetail,
        serviceNumber: String,
        amount: Double,
        isLoggedIn: Bool = true
    ) -> AddToCartResult {
        let number = serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.id.isEmpty, !number.isEmpty, amount > 0 else { return .success }
        if isLoggedIn && !hasValidDeliveryAddress {
            pendingCartAdd = .servicePayment(service: service, serviceNumber: number, amount: amount)
            return .needsAddress
        }
        return performAddServiceToCart(service: service, serviceNumber: number, amount: amount)
    }

    /// Returns outcome so UI can show car-wash alert or open address search.
    @discardableResult
    func addShopProductToCart(
        _ product: ShopProduct,
        pickupLatitude: Double?,
        pickupLongitude: Double?,
        shopId: String,
        shopType: String? = nil,
        isLoggedIn: Bool = true
    ) -> AddToCartResult {
        if isLoggedIn && !hasValidDeliveryAddress {
            pendingCartAdd = .shopProduct(
                product: product,
                pickupLatitude: pickupLatitude,
                pickupLongitude: pickupLongitude,
                shopId: shopId,
                shopType: shopType
            )
            return .needsAddress
        }
        return performAddShopProductToCart(
            product,
            pickupLatitude: pickupLatitude,
            pickupLongitude: pickupLongitude,
            shopId: shopId,
            shopType: shopType
        )
    }

    func clearPendingCartAdd() {
        pendingCartAdd = nil
    }

    /// Call after the address flow finishes (save or select). Resumes pending add if address is valid.
    func resumePendingCartAddIfPossible() async -> AddToCartResult? {
        await refreshAddresses()
        guard let pending = pendingCartAdd else { return nil }
        guard hasValidDeliveryAddress else {
            pendingCartAdd = nil
            return nil
        }
        pendingCartAdd = nil
        switch pending {
        case let .shopProduct(product, pickupLatitude, pickupLongitude, shopId, shopType):
            return performAddShopProductToCart(
                product,
                pickupLatitude: pickupLatitude,
                pickupLongitude: pickupLongitude,
                shopId: shopId,
                shopType: shopType
            )
        case let .productDetail(route, quantity, detail):
            return performAddProductToCart(route, quantity: quantity, detail: detail)
        case let .servicePayment(service, serviceNumber, amount):
            return performAddServiceToCart(service: service, serviceNumber: serviceNumber, amount: amount)
        }
    }

    private func performAddProductToCart(
        _ product: ProductDetailRoute,
        quantity: Int,
        detail: ProductDetail? = nil
    ) -> AddToCartResult {
        let route: ProductDetailRoute
        if let detail {
            route = ProductDetailRoute(
                detail: detail,
                pickupLatitude: product.pickupLatitude,
                pickupLongitude: product.pickupLongitude,
                shopId: product.shopId
            )
        } else {
            route = product
        }
        let validDiscount = max(0, min(100, route.discount))
        let showPromotion = route.hasPromotion && validDiscount > 0
        let unitAfterDiscount = route.unitPriceAfterDiscount
        let list = route.price
        let resolvedShopId = CartShopSwitchPolicy.normalized(route.shopId)
            ?? CartShopSwitchPolicy.normalized(detail?.shopId)
            ?? CartShopSwitchPolicy.normalized(product.shopId)
        let shopType = detail?.shopType
            ?? featuredPlaces.first(where: { $0.id == resolvedShopId && !$0.isService })?.shopType

        clearServiceLinesFromCart()

        if CartCarWashSingleProductPolicy.blocksAdd(
            shopType: shopType,
            lines: cartLines,
            productId: route.id,
            shopId: resolvedShopId,
            quantityToAdd: quantity
        ) {
            return .blockedCarWash
        }

        if let i = cartLines.firstIndex(where: { $0.productId == route.id }) {
            cartLines[i].quantity += quantity
            if cartLines[i].pickupLatitude == nil, let p = route.pickupLatitude { cartLines[i].pickupLatitude = p }
            if cartLines[i].pickupLongitude == nil, let p = route.pickupLongitude { cartLines[i].pickupLongitude = p }
            if CartShopSwitchPolicy.normalized(cartLines[i].shopId) == nil, let s = resolvedShopId {
                cartLines[i].shopId = s
            }
        } else {
            cartLines.append(
                CartLineItem(
                    productId: route.id,
                    name: route.name,
                    imageUrl: route.imageUrl,
                    quantity: quantity,
                    unitPrice: unitAfterDiscount,
                    listUnitPrice: list,
                    hasPromotion: showPromotion,
                    discount: validDiscount,
                    pickupLatitude: route.pickupLatitude,
                    pickupLongitude: route.pickupLongitude,
                    shopId: resolvedShopId,
                    lineKind: CartLineKinds.product
                )
            )
        }
        cartLocalStore.persist(lines: cartLines)
        return .success
    }

    private func performAddShopProductToCart(
        _ product: ShopProduct,
        pickupLatitude: Double?,
        pickupLongitude: Double?,
        shopId: String,
        shopType: String? = nil
    ) -> AddToCartResult {
        let validDiscount = max(0, min(100, product.discount))
        let showPromotion = product.hasPromotion && validDiscount > 0
        let unitAfterDiscount = showPromotion
            ? product.price * (1 - Double(validDiscount) / 100)
            : product.price
        let resolvedShopId = CartShopSwitchPolicy.normalized(product.shopId)
            ?? CartShopSwitchPolicy.normalized(shopId)
        let resolvedType = shopType
            ?? featuredPlaces.first(where: { $0.id == resolvedShopId && !$0.isService })?.shopType

        clearServiceLinesFromCart()

        if CartCarWashSingleProductPolicy.blocksAdd(
            shopType: resolvedType,
            lines: cartLines,
            productId: product.id,
            shopId: resolvedShopId,
            quantityToAdd: 1
        ) {
            return .blockedCarWash
        }

        if let i = cartLines.firstIndex(where: { $0.productId == product.id }) {
            cartLines[i].quantity += 1
            if cartLines[i].pickupLatitude == nil, let lat = pickupLatitude { cartLines[i].pickupLatitude = lat }
            if cartLines[i].pickupLongitude == nil, let lng = pickupLongitude { cartLines[i].pickupLongitude = lng }
            if CartShopSwitchPolicy.normalized(cartLines[i].shopId) == nil, let s = resolvedShopId {
                cartLines[i].shopId = s
            }
        } else {
            cartLines.append(
                CartLineItem(
                    productId: product.id,
                    name: product.name,
                    imageUrl: product.imageUrl,
                    quantity: 1,
                    unitPrice: unitAfterDiscount,
                    listUnitPrice: product.price,
                    hasPromotion: showPromotion,
                    discount: validDiscount,
                    pickupLatitude: pickupLatitude,
                    pickupLongitude: pickupLongitude,
                    shopId: resolvedShopId,
                    lineKind: CartLineKinds.product
                )
            )
        }
        cartLocalStore.persist(lines: cartLines)
        return .success
    }

    private func performAddServiceToCart(
        service: ServiceDetail,
        serviceNumber: String,
        amount: Double
    ) -> AddToCartResult {
        let number = serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.id.isEmpty, !number.isEmpty, amount > 0 else { return .success }
        clearProductLinesFromCart()
        let lineId = CartLineKinds.serviceLineId(serviceId: service.id, serviceNumber: number)
        let line = CartLineItem(
            productId: lineId,
            name: service.name,
            imageUrl: service.imageUrl,
            quantity: 1,
            unitPrice: amount,
            listUnitPrice: 0,
            hasPromotion: false,
            discount: 0,
            pickupLatitude: service.lat,
            pickupLongitude: service.lng,
            shopId: nil,
            lineKind: CartLineKinds.service,
            serviceId: service.id,
            serviceNumber: number
        )
        if let i = cartLines.firstIndex(where: { $0.productId == lineId }) {
            cartLines[i] = line
        } else {
            cartLines.append(line)
        }
        cartLocalStore.persist(lines: cartLines)
        return .success
    }

    private func clearServiceLinesFromCart() {
        cartLines.removeAll { $0.isServicePayment }
    }

    private func clearProductLinesFromCart() {
        cartLines.removeAll { !$0.isServicePayment }
    }

    func removeCartLine(productId: String) {
        cartLines.removeAll { $0.productId == productId }
        cartLocalStore.persist(lines: cartLines)
    }

    func clearCart() {
        cartLines = []
        cartLocalStore.persist(lines: cartLines)
    }

    func needsShopSwitchConfirmation(for targetShopId: String) -> Bool {
        CartShopSwitchPolicy.needsConfirmation(lines: cartLines, targetShopId: targetShopId)
    }

    init(
        placesRepository: PlacesRepository,
        adsRepository: AdsRepository,
        userAddressRepository: UserAddressRepository,
        orderRepository: OrderRepository,
        deliveryPricingConfigRepository: DeliveryPricingConfigRepository,
        http: DobbyHTTPClient,
        cartLocalStore: CartLocalStore
    ) {
        self.placesRepository = placesRepository
        self.adsRepository = adsRepository
        self.userAddressRepository = userAddressRepository
        self.orderRepository = orderRepository
        self.deliveryPricingConfigRepository = deliveryPricingConfigRepository
        self.http = http
        self.cartLocalStore = cartLocalStore
        cartLines = cartLocalStore.loadLines()
        deliveryPricingSettings = deliveryPricingConfigRepository.currentSettings()
        Task { await refreshDeliveryPricing() }
    }

    func refreshDeliveryPricing() async {
        await deliveryPricingConfigRepository.refresh()
        deliveryPricingSettings = deliveryPricingConfigRepository.currentSettings()
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
        await refreshDeliveryPricing()
        await refreshShopCoords()
        let deliveryFee = orderPricing?.delivery.finalDeliveryFee ?? 0
        if deliveryFee <= 0, orderPricing == nil, hasValidDeliveryAddress {
            cartPayError = "No se pudo calcular el envío. Actualiza el carrito e intenta de nuevo."
            isCheckoutLoading = false
            return false
        }
        let isServicePaymentCart = cartLines.allSatisfy(\.isServicePayment)
        let createResult: Result<Void, OrderRepositoryError>
        if isServicePaymentCart {
            createResult = await orderRepository.createServicePaymentOrder(
                addressId: addressId,
                items: cartLines,
                deliveryFee: deliveryFee
            )
        } else {
            createResult = await orderRepository.createOrder(
                addressId: addressId,
                items: cartLines,
                deliveryFee: deliveryFee
            )
        }
        switch createResult {
        case .success:
            cartLines = []
            cartLocalStore.persist(lines: [])
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            isCheckoutLoading = false
            await loadActiveOrder()
            return true
        case .failure(let e):
            isCheckoutLoading = false
            switch e {
            case .notAuthenticated:
                cartPayError = "Inicia sesión para realizar tu pedido."
            default:
                if !e.shouldSuppressUserMessage {
                    cartPayError = message(for: e)
                }
            }
            return false
        }
    }

    private func message(for error: OrderRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .invalidRequest(let msg):
            return msg
        case .http(let he):
            return http.userFacingMessage(from: he)
        }
    }

    /// - Parameter clearOnFailure: `false` en pull-to-refresh para no borrar pedidos si la red falla o cancela la tarea.
    func loadActiveOrder(clearOnFailure: Bool = true) async {
        switch await orderRepository.getActiveOrders() {
        case .success(let orders):
            activeOrders = orders
        case .failure(let error):
            if !clearOnFailure {
                applyNonSuppressedWarning(from: error)
                return
            }
            guard !shouldPreserveExistingData(on: error) else { return }
            activeOrders = []
        }
    }

    func onSearchQueryChange(_ q: String) {
        searchQuery = q
    }

    func clearWarningMessage() {
        warningMessage = nil
    }

    private func applyHomeData(_ data: HomeData) {
        featuredPlaces = HomeShopHours.sortFeaturedPlacesByAvailability(places: data.featuredPlaces)
        bestSellerProducts = HomeShopHours.sortBestSellersByShopAvailability(
            products: data.bestSellerProducts,
            featuredPlaces: data.featuredPlaces
        )
    }

    func loadInitial() {
        if let snapshot = HomeBootstrapCache.shared.consume() {
            applyBootstrap(snapshot)
            return
        }
        isLoading = true
        errorMessage = nil
        warningMessage = nil
        loadAddresses()
        Task {
            async let pricingTask: Void = refreshDeliveryPricing()
            await refreshShopCoords()
            await pricingTask
            switch await placesRepository.getHome() {
            case .success(let data):
                applyHomeData(data)
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

    private func applyBootstrap(_ snapshot: HomeBootstrapSnapshot) {
        featuredPlaces = HomeShopHours.sortFeaturedPlacesByAvailability(places: snapshot.featuredPlaces)
        bestSellerProducts = HomeShopHours.sortBestSellersByShopAvailability(
            products: snapshot.bestSellerProducts,
            featuredPlaces: snapshot.featuredPlaces
        )
        ads = snapshot.ads
        activeOrders = snapshot.activeOrders
        addressLabel = snapshot.addressLabel
        address = snapshot.address
        addressDetails = snapshot.addressDetails
        defaultAddressId = snapshot.defaultAddressId
        deliveryLatitude = snapshot.deliveryLatitude
        deliveryLongitude = snapshot.deliveryLongitude
        addressFetchCompleted = snapshot.addressFetchCompleted
        needsDeliveryAddressCallout = snapshot.needsDeliveryAddressCallout
        warningMessage = snapshot.warningMessage
        errorMessage = snapshot.errorMessage
        deliveryPricingSettings = snapshot.deliveryPricingSettings
        shopCoordsByShopId = snapshot.shopCoordsByShopId
        isLoading = false
    }

    func loadHome() {
        Task {
            isLoading = true
            errorMessage = nil
            warningMessage = nil
            switch await placesRepository.getHome() {
            case .success(let data):
                applyHomeData(data)
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
                applyAddressList(list)
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

    private func applyAddressList(_ list: [UserAddress]) {
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
    }

    private static func normalizedAddressDetails(from raw: String?) -> String? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    /// - Parameter clearOnFailure: `false` en pull-to-refresh para conservar anuncios ya cargados.
    private func loadAds(clearOnFailure: Bool = true) async {
        switch await adsRepository.getAds() {
        case .success(let list):
            ads = list
        case .failure(let e):
            guard clearOnFailure, !shouldPreserveExistingData(on: e) else {
                applyNonSuppressedWarning(from: e)
                return
            }
            ads = []
            applyNonSuppressedWarning(from: e)
        }
    }

    func recordAdClick(adId: String) {
        Task { await adsRepository.recordAdClick(id: adId) }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshHomeData()
    }

    /// Silent refresh when the app returns from background (no pull-to-refresh spinner).
    func refreshOnForeground() async {
        await refreshHomeData()
    }

    private func refreshHomeData() async {
        errorMessage = nil

        // Pedidos, direcciones y anuncios: detached para que no se cancelen al soltar el pull-to-refresh.
        Task.detached { @MainActor [weak self] in
            await self?.loadActiveOrder(clearOnFailure: false)
        }
        Task.detached { @MainActor [weak self] in
            await self?.refreshAddresses()
        }
        Task.detached { @MainActor [weak self] in
            await self?.refreshHome()
        }
        Task.detached { @MainActor [weak self] in
            await self?.loadAds(clearOnFailure: false)
        }

        async let shopCoordsTask: Void = refreshShopCoords()
        async let pricingTask: Void = refreshDeliveryPricing()
        _ = await (shopCoordsTask, pricingTask)
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
            applyHomeData(data)
            errorMessage = nil
        case .failure(let e):
            guard !shouldPreserveExistingData(on: e) else {
                applyNonSuppressedWarning(from: e)
                return
            }
            if !e.shouldSuppressUserMessage {
                errorMessage = message(for: e)
            }
        }
    }

    private func refreshAddresses() async {
        switch await userAddressRepository.getAddresses() {
        case .success(let list):
            applyAddressList(list)
        case .failure(let e):
            guard !shouldPreserveExistingData(on: e) else {
                applyNonSuppressedWarning(from: e)
                return
            }
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

    /// No borrar datos por cancelación del refresh o errores de auth suprimidos (p. ej. 401 en vuelo).
    private func shouldPreserveExistingData(on error: Error) -> Bool {
        if Task.isCancelled { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        if let e = error as? HomeRepositoryError, e.shouldSuppressUserMessage { return true }
        if let e = error as? OrderRepositoryError, e.shouldSuppressUserMessage { return true }
        return false
    }

    private func applyNonSuppressedWarning(from error: Error) {
        if let e = error as? HomeRepositoryError, !e.shouldSuppressUserMessage {
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
        if let e = error as? OrderRepositoryError, !e.shouldSuppressUserMessage {
            switch e {
            case .http(let he):
                warningMessage = http.userFacingMessage(from: he)
            case .invalidRequest(let msg):
                warningMessage = msg
            case .notAuthenticated:
                break
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
