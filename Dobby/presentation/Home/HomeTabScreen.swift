//
//  HomeTabScreen.swift
//  Dobby
//

import SwiftUI
import UIKit

private enum HomePalette {
    static let primary = HomeScreenPalette.primary
}

/// Single navigation stack so Back always pops one level (shop → product → cart), never jumps to home.
private enum HomeStackRoute: Hashable {
    case shop(ShopDetailRoute)
    case featuredPlaces
    case bestSellers
    case product(ProductDetailRoute)
    case service(serviceId: String)
    case ad(adId: String)
    case cart
    case activeOrders
    case orderTracking(orderId: String)
}

struct HomeTabScreen: View {
    @Bindable var viewModel: HomeTabViewModel
    let placesRepository: PlacesRepository
    let adsRepository: AdsRepository
    let favoritesStore: FavoritesStore
    let userAddressRepository: UserAddressRepository
    let placesAutocompleteRepository: PlacesAutocompleteRepository
    let orderRepository: OrderRepository
    let directionsRepository: DirectionsRepository
    let httpClient: DobbyHTTPClient
    /// When `true`, `MainTabView` hides the bottom floating tab bar (e.g. shop detail is visible).
    @Binding var mainTabBarHidden: Bool
    /// After a successful `Pagar`, switch to Inicio (no-op if already there) so the user sees order tracking.
    let onCheckoutSuccess: () -> Void
    let onPromotionsTabClick: () -> Void
    /// Set from push tap (e.g. repartidor asignado) — navigate to order tracking when non-nil.
    @Binding var pendingOpenOrderTrackingId: String?
    @Binding var pendingOpenProductId: String?
    @Binding var pendingOpenProductShopId: String?
    @Binding var pendingOpenProductName: String?
    @Binding var pendingOpenProductDiscount: Int?
    let tokenRefresh: ConsumerTokenRefreshService

    @State private var showCurrentAddress = false
    @State private var navigationPath: [HomeStackRoute] = []
    @State private var quickCategory: HomeQuickCategory = .all
    @State private var productPromotionDeepLinkTask: Task<Void, Never>?
    @State private var showShopSwitchAlert = false
    @State private var pendingShopPlace: FeaturedPlace?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            homeContent
                .navigationDestination(for: HomeStackRoute.self) { route in
                    switch route {
                    case .shop(let r):
                        ShopDetailScreen(
                            shopId: r.shopId,
                            shopName: r.shopName,
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onProductTap: { product, isAvailable in
                                navigationPath.append(
                                    .product(
                                        ProductDetailRoute(
                                            shopProduct: product,
                                            pickupLatitude: r.pickupLatitude,
                                            pickupLongitude: r.pickupLongitude,
                                            isShopAvailableForOrders: isAvailable
                                        )
                                    )
                                )
                            },
                            onAddToCart: { product in
                                viewModel.addShopProductToCart(
                                    product,
                                    pickupLatitude: r.pickupLatitude,
                                    pickupLongitude: r.pickupLongitude,
                                    shopId: r.shopId
                                )
                            },
                            onCartClick: {
                                navigationPath.append(.cart)
                            }
                        )
                    case .featuredPlaces:
                        FeaturedPlacesScreen(
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            onBack: { popNavigation() },
                            onPlaceTap: { onFeaturedPlaceTap($0) }
                        )
                    case .bestSellers:
                        BestSellersScreen(
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onProductTap: { product, isAvailable in
                                let place = viewModel.featuredPlaces.first {
                                    $0.id == product.shopId && !$0.isService
                                }
                                navigationPath.append(
                                    .product(
                                        ProductDetailRoute(
                                            shopProduct: product,
                                            pickupLatitude: place?.latitude,
                                            pickupLongitude: place?.longitude,
                                            isShopAvailableForOrders: isAvailable
                                        )
                                    )
                                )
                            },
                            onAddToCart: { product in
                                let shopId = product.shopId ?? ""
                                let place = viewModel.featuredPlaces.first { $0.id == shopId && !$0.isService }
                                viewModel.addShopProductToCart(
                                    product,
                                    pickupLatitude: place?.latitude,
                                    pickupLongitude: place?.longitude,
                                    shopId: shopId
                                )
                            },
                            onCartClick: {
                                navigationPath.append(.cart)
                            }
                        )
                    case .service(let serviceId):
                        ServiceDetailScreen(
                            serviceId: serviceId,
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onCartClick: {
                                navigationPath.append(.cart)
                            }
                        )
                    case .ad(let adId):
                        AdDetailScreen(
                            adId: adId,
                            adsRepository: adsRepository,
                            httpClient: httpClient,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onCartClick: {
                                navigationPath.append(.cart)
                            }
                        )
                    case .product(let r):
                        ProductDetailScreen(
                            product: r,
                            placesRepository: placesRepository,
                            tokenRefresh: tokenRefresh,
                            favoritesStore: favoritesStore,
                            cartItemCount: viewModel.cartItemCount,
                            userLatitude: viewModel.deliveryLatitude,
                            userLongitude: viewModel.deliveryLongitude,
                            onBack: { popNavigation() },
                            onCartClick: {
                                navigationPath.append(.cart)
                            },
                            onAddToCart: { quantity, detail in
                                viewModel.addProductToCart(r, quantity: quantity, detail: detail)
                                navigationPath.append(.cart)
                            }
                        )
                    case .cart:
                        CartScreen(
                            viewModel: viewModel,
                            onBack: { popNavigation() },
                            onPay: {
                                Task {
                                    let ok = await viewModel.runCheckoutFlow()
                                    if ok {
                                        navigationPath.removeAll()
                                        onCheckoutSuccess()
                                    }
                                }
                            }
                        )
                    case .activeOrders:
                        ActiveOrdersScreen(
                            activeOrders: viewModel.activeOrders,
                            onTrackOrder: { orderId in
                                navigationPath.append(.orderTracking(orderId: orderId))
                            }
                        )
                    case .orderTracking(let orderId):
                        OrderTrackingScreen(
                            orderId: orderId,
                            orderRepository: orderRepository,
                            directionsRepository: directionsRepository,
                            http: httpClient,
                            onBack: { popNavigation() },
                            onFinish: {
                                navigationPath.removeAll()
                                Task { await viewModel.loadActiveOrder() }
                            }
                        )
                    }
                }
        }
        .onChange(of: navigationPath) { _, _ in
            syncMainTabBarHiddenWithNavigation()
        }
        .onAppear {
            syncMainTabBarHiddenWithNavigation()
        }
    }

    private func syncMainTabBarHiddenWithNavigation() {
        mainTabBarHidden = !navigationPath.isEmpty
    }

    private func popNavigation() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    private func openOrderTrackingIfNeeded(_ orderId: String?) {
        guard let orderId = orderId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !orderId.isEmpty else { return }
        pendingOpenOrderTrackingId = nil
        Task {
            switch await orderRepository.getOrderTracking(orderId: orderId) {
            case .success(let detail):
                guard let detail, OrderPushNavigation.canOpenTracking(status: detail.status) else {
                    navigationPath.removeAll()
                    await viewModel.loadActiveOrder()
                    return
                }
                navigationPath.append(.orderTracking(orderId: orderId))
                await viewModel.loadActiveOrder()
            case .failure:
                navigationPath.removeAll()
                await viewModel.loadActiveOrder()
            }
        }
    }

    private func scheduleOpenProductPromotionIfNeeded(
        productId: String?,
        shopId: String?,
        productName: String?,
        discountPercent: Int?
    ) {
        guard let productId = productId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !productId.isEmpty else { return }
        let trimmedShop = shopId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedShop = (trimmedShop?.isEmpty == false) ? trimmedShop : nil
        let trimmedName = productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedName?.isEmpty == false) ? trimmedName : nil
        let resolvedDiscount = discountPercent.map { max(1, min(100, $0)) }

        pendingOpenProductId = nil
        pendingOpenProductShopId = nil
        pendingOpenProductName = nil
        pendingOpenProductDiscount = nil

        if navigationPath.contains(where: { route in
            if case .product(let r) = route { return r.id == productId }
            return false
        }) {
            return
        }

        productPromotionDeepLinkTask?.cancel()
        productPromotionDeepLinkTask = Task { @MainActor in
            await tokenRefresh.refreshAccessTokenOnForeground()
            var waits = 0
            while viewModel.isLoading && waits < 40 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waits += 1
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            if navigationPath.contains(where: { route in
                if case .product(let r) = route { return r.id == productId }
                return false
            }) {
                return
            }
            let route = ProductDetailRoute(
                promotionPush: productId,
                shopId: resolvedShop,
                productName: resolvedName,
                discountPercent: resolvedDiscount,
                isShopAvailableForOrders: HomeShopHours.isProductShopAvailableForOrders(
                    shopId: resolvedShop,
                    featuredPlaces: viewModel.featuredPlaces
                )
            )
            navigationPath.append(.product(route))
        }
    }

    private var homeContent: some View {
        Group {
            if let err = viewModel.errorMessage, viewModel.featuredPlaces.isEmpty, !viewModel.isLoading {
                VStack(spacing: 16) {
                    Text(err)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        viewModel.loadHome()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomePalette.primary)
                }
            } else if viewModel.isLoading && viewModel.featuredPlaces.isEmpty {
                ProgressView()
                    .tint(HomePalette.primary)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomeScreenPalette.screenBackground)
        .onAppear {
            viewModel.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: DobbyOrderRealtime.orderChangedNotification)) { _ in
            Task { await viewModel.loadActiveOrder() }
        }
        .onChange(of: pendingOpenOrderTrackingId) { _, orderId in
            openOrderTrackingIfNeeded(orderId)
        }
        .onChange(of: pendingOpenProductId) { _, productId in
            scheduleOpenProductPromotionIfNeeded(
                productId: productId,
                shopId: pendingOpenProductShopId,
                productName: pendingOpenProductName,
                discountPercent: pendingOpenProductDiscount
            )
        }
        .onAppear {
            openOrderTrackingIfNeeded(pendingOpenOrderTrackingId)
            scheduleOpenProductPromotionIfNeeded(
                productId: pendingOpenProductId,
                shopId: pendingOpenProductShopId,
                productName: pendingOpenProductName,
                discountPercent: pendingOpenProductDiscount
            )
        }
        .fullScreenCover(isPresented: $showCurrentAddress) {
            NavigationStack {
                CurrentAddressScreen(
                    placesAutocompleteRepository: placesAutocompleteRepository,
                    userAddressRepository: userAddressRepository,
                    httpClient: httpClient,
                    onDefaultAddressUpdated: { viewModel.loadAddresses() }
                )
            }
        }
        .alert("¿Cambiar de tienda?", isPresented: $showShopSwitchAlert) {
            Button("Cancelar", role: .cancel) {
                pendingShopPlace = nil
            }
            Button("Continuar", role: .destructive) {
                viewModel.clearCart()
                if let place = pendingShopPlace {
                    navigateToShop(place)
                }
                pendingShopPlace = nil
            }
        } message: {
            Text("Si entras a otra tienda perderás los productos de tu carrito actual.")
        }
    }

    private func navigateToShop(_ place: FeaturedPlace) {
        navigationPath.append(
            .shop(
                ShopDetailRoute(
                    shopId: place.id,
                    shopName: place.name,
                    pickupLatitude: place.latitude,
                    pickupLongitude: place.longitude
                )
            )
        )
    }

    private func onFeaturedPlaceTap(_ place: FeaturedPlace) {
        if place.isService {
            navigationPath.append(.service(serviceId: place.id))
            return
        }
        if viewModel.needsShopSwitchConfirmation(for: place.id) {
            pendingShopPlace = place
            showShopSwitchAlert = true
        } else {
            navigateToShop(place)
        }
    }

    private var content: some View {
        let screenW = UIScreen.main.bounds.width
        let featuredCardWidth = HomeLayoutConstants.featuredCardWidth(screenWidth: screenW)
        let productWidth = HomeLayoutConstants.productCardWidth(featuredWidth: featuredCardWidth)

        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryPlaces = filterPlacesByCategory(viewModel.featuredPlaces, category: quickCategory)
        let filteredPlaces = categoryPlaces.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        let categoryProducts: [BestSellerProduct] = {
            if quickCategory == .offers {
                return viewModel.bestSellerProducts.filter { $0.hasPromotion && $0.discount > 0 }
            }
            return viewModel.bestSellerProducts
        }()
        let filteredProducts = categoryProducts.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        let destacadosPreview = Array(filteredPlaces.prefix(HomeLayoutConstants.destacadosPreviewLimit))
        let bestSellersPreview = Array(filteredProducts.prefix(HomeLayoutConstants.bestSellersPreviewLimit))
        let restaurantsOnly = filteredPlaces.filter { !$0.isService && ($0.shopType == "RESTAURANT" || $0.shopType == nil) }
        let servicesOnly = filteredPlaces.filter(\.isService)

        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let warn = viewModel.warningMessage {
                    warningBanner(warn)
                }

                HomeAddressSearchHeader(
                    addressLabel: viewModel.addressLabel,
                    address: viewModel.address,
                    searchQuery: $viewModel.searchQuery,
                    onAddressClick: { showCurrentAddress = true }
                ) {
                    if viewModel.addressFetchCompleted,
                       viewModel.needsDeliveryAddressCallout,
                       viewModel.warningMessage == nil {
                        DeliveryAddressCalloutView(onTap: { showCurrentAddress = true })
                            .padding(.horizontal, 13)
                            .padding(.top, 0)
                            .padding(.bottom, 4)
                    }
                }

                HomeCategoryRow(selected: quickCategory) { category in
                    quickCategory = category
                    if category == .offers {
                        onPromotionsTabClick()
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !viewModel.activeOrders.isEmpty {
                            ActiveOrdersHomeSectionView(
                                activeOrders: viewModel.activeOrders,
                                onTrackOrder: { orderId in
                                    navigationPath.append(.orderTracking(orderId: orderId))
                                },
                                onMultipleOrdersTap: {
                                    navigationPath.append(.activeOrders)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }

                        if !destacadosPreview.isEmpty {
                            HomeSectionHeader(title: "Destacados")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(destacadosPreview) { place in
                                        HomeFeaturedPlaceCard(
                                            place: place,
                                            width: featuredCardWidth,
                                            onTap: { onFeaturedPlaceTap(place) }
                                        )
                                    }
                                    HomeFeaturedSeeMoreCard(width: featuredCardWidth) {
                                        navigationPath.append(.featuredPlaces)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                            .background(DobbyPureScale.pure)
                            .padding(.bottom, 10)
                        }

                        if !bestSellersPreview.isEmpty {
                            HomeSectionHeader(title: "Más vendidos")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(bestSellersPreview) { product in
                                        Button {
                                            navigationPath.append(
                                                .product(ProductDetailRoute(
                                                    bestSeller: product,
                                                    featuredPlaces: viewModel.featuredPlaces
                                                ))
                                            )
                                        } label: {
                                            UniversalProductCard(product: product, width: productWidth)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    HomeProductSeeMoreCard(width: productWidth, onTap: {
                                        navigationPath.append(.bestSellers)
                                    })
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                            .background(DobbyPureScale.pure)
                            .padding(.bottom, 10)
                        }

                        if !query.isEmpty && filteredPlaces.isEmpty && filteredProducts.isEmpty {
                            Text("Sin resultados para \"\(query)\"")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }

                        if viewModel.ads.isEmpty {
                            HomePromoBanner()
                        }

                        if !viewModel.ads.isEmpty {
                            AdsCarousel(
                                slides: AdCarouselSlide.weighted(from: viewModel.ads),
                                onAdTap: { adId in
                                    viewModel.recordAdClick(adId: adId)
                                    navigationPath.append(.ad(adId: adId))
                                }
                            )
                        }

                        if !restaurantsOnly.isEmpty {
                            HomeSectionHeader(title: "Restaurantes populares")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(restaurantsOnly) { place in
                                        HomeFeaturedPlaceCard(
                                            place: place,
                                            width: featuredCardWidth,
                                            onTap: { onFeaturedPlaceTap(place) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            .background(DobbyPureScale.pure)
                            .padding(.bottom, 20)
                        }

                        if !servicesOnly.isEmpty {
                            HomeSectionHeader(title: "Servicios destacados")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(servicesOnly) { place in
                                        HomeServicePlaceRow(place: place) {
                                            onFeaturedPlaceTap(place)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            .background(DobbyPureScale.pure)
                            .padding(.bottom, 8)
                        }

                        Color.clear.frame(height: 8 + HomeLayoutConstants.mainTabContentBottomInset)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DobbyPureScale.pure)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DobbyPureScale.pure)
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HomeScreenPalette.screenBackground)

            Button {
                navigationPath.append(.cart)
            } label: {
                HomeCartIconBadge(count: viewModel.cartItemCount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Carrito")
            .padding(.trailing, 4)
            .padding(.top, 4)
        }
    }

    private func warningBanner(_ msg: String) -> some View {
        HStack {
            Text(msg)
                .font(.caption)
                .foregroundStyle(DobbyBrandColor.dark)
            Spacer(minLength: 8)
            Button("Cerrar") {
                viewModel.clearWarningMessage()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(DobbyBrandColor.warningBackground)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Add address callout (parity with Android `DeliveryAddressCallout`)

/// Tail on **top**, tip biased to the left (mirror of the previous right layout).
private struct CalloutTriangleUp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tipX = rect.width * 0.22
        p.move(to: CGPoint(x: tipX, y: 0))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct DeliveryAddressCalloutView: View {
    private static let blue = DobbyBrandColor.primary
    let onTap: () -> Void
    @State private var bobUp = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: 10)
                CalloutTriangleUp()
                    .fill(Self.blue)
                    .frame(width: 22, height: 10)
                    .padding(.leading, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text("Añade tu dirección de entrega")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                Text("Toca aquí para agregar una dirección y descubrir qué restaurantes pueden entregarte")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Self.blue)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture(perform: onTap)
        }
        .offset(y: bobUp ? -7 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                bobUp = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Añade tu dirección de entrega. Toca para abrir el mapa y guardarla.")
    }
}

// MARK: - Ads (paridad con Android `LazyRow` + auto-scroll ~ViewPager)

private struct AdsCarousel: View {
    let slides: [AdCarouselSlide]
    let onAdTap: (String) -> Void
    @State private var visibleSlideId: String?

    private let cardHeight: CGFloat = 160
    private let autoAdvanceNanos: UInt64 = 2_000_000_000

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(slides) { slide in
                    Button {
                        onAdTap(slide.ad.id)
                    } label: {
                        adPageView(ad: slide.ad)
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                    .id(slide.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visibleSlideId)
        .frame(height: cardHeight)
        .padding(.vertical, 12)
        .onAppear {
            if visibleSlideId == nil { visibleSlideId = slides.first?.id }
        }
        .task(id: slides.map(\.id).joined(separator: "|")) {
            guard !slides.isEmpty else { return }
            if visibleSlideId == nil || !slides.contains(where: { $0.id == visibleSlideId }) {
                visibleSlideId = slides.first?.id
            }
            guard slides.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: autoAdvanceNanos)
                guard let current = visibleSlideId,
                      let idx = slides.firstIndex(where: { $0.id == current }) else {
                    visibleSlideId = slides.first?.id
                    continue
                }
                let nextIdx = (idx + 1) % slides.count
                withAnimation(.easeInOut(duration: 0.45)) {
                    visibleSlideId = slides[nextIdx].id
                }
            }
        }
    }

    @ViewBuilder
    private func adPageView(ad: Ad) -> some View {
        LoadingRemoteImage(urlString: ad.imageUrl) {
            adPlaceholderMonogram(ad: ad)
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    private func adPlaceholderMonogram(ad: Ad) -> some View {
        Text(String(ad.name.prefix(1)).uppercased())
            .font(.largeTitle.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
