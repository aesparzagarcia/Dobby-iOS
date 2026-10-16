//
//  PromotionsTabScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.promotions.PromotionsTabScreen`.
//

import SwiftUI
import UIKit

private enum PromotionsPalette {
    static let primary = DobbyBrandColor.primary
}

/// Routes for the promotions tab `NavigationStack` (product detail + cart).
private enum PromotionsStackRoute: Hashable {
    case product(ProductDetailRoute)
    case shop(ShopDetailRoute)
    case cart
}

struct PromotionsTabScreen: View {
    let placesRepository: PlacesRepository
    let placesAutocompleteRepository: PlacesAutocompleteRepository
    let userAddressRepository: UserAddressRepository
    let httpClient: DobbyHTTPClient
    let favoritesStore: FavoritesStore
    @Bindable var promotionsViewModel: PromotionsTabViewModel
    @Bindable var homeViewModel: HomeTabViewModel
    @Binding var mainTabBarHidden: Bool
    let onCheckoutSuccess: () -> Void
    let isLoggedIn: Bool
    let onRequireLogin: () -> Void

    @State private var navigationPath: [PromotionsStackRoute] = []
    @State private var showCurrentAddress = false
    @State private var pendingOpenCartAfterAddress = false
    @State private var showShopSwitchAlert = false
    @State private var pendingProductRoute: ProductDetailRoute?

    private func openAddressForPendingCart(openCartAfter: Bool = false) {
        pendingOpenCartAfterAddress = openCartAfter
        showCurrentAddress = true
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            promotionsRoot
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: PromotionsStackRoute.self) { route in
                    switch route {
                    case .product(let r):
                        ProductDetailScreen(
                            product: r,
                            placesRepository: placesRepository,
                            favoritesStore: favoritesStore,
                            cartItemCount: homeViewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onCartClick: {
                                pushCartIfNeeded()
                            },
                            onAddToCart: { quantity, detail, variant in
                                let result = homeViewModel.addProductToCart(
                                    r,
                                    quantity: quantity,
                                    detail: detail,
                                    variant: variant,
                                    isLoggedIn: isLoggedIn
                                )
                                if result == .success {
                                    openCartAfterAddingFromProduct()
                                }
                                return result
                            },
                            onNeedsAddress: {
                                openAddressForPendingCart(openCartAfter: true)
                            },
                            onCancelNeedsAddress: {
                                homeViewModel.clearPendingCartAdd()
                                pendingOpenCartAfterAddress = false
                            },
                            onClearCart: { homeViewModel.clearCart() },
                            onShopTap: { shopId, shopName, shopType in
                                openShopFromProduct(
                                    shopId: shopId,
                                    shopName: shopName,
                                    shopType: shopType,
                                    pickupLatitude: r.pickupLatitude,
                                    pickupLongitude: r.pickupLongitude
                                )
                            }
                        )
                    case .shop(let r):
                        ShopDetailScreen(
                            shopId: r.shopId,
                            shopName: r.shopName,
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            cartItemCount: homeViewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onProductTap: { product, isAvailable, shopStatus, shopReopensLabel in
                                openProduct(
                                    ProductDetailRoute(
                                        shopProduct: product,
                                        pickupLatitude: r.pickupLatitude,
                                        pickupLongitude: r.pickupLongitude,
                                        isShopAvailableForOrders: isAvailable,
                                        shopIdFallback: r.shopId,
                                        shopStatus: shopStatus,
                                        shopReopensLabel: shopReopensLabel,
                                        shopName: r.shopName,
                                        shopType: r.shopType
                                    )
                                )
                            },
                            onAddToCart: { product, shopType, variant, quantity in
                                return homeViewModel.addShopProductToCart(
                                    product,
                                    pickupLatitude: r.pickupLatitude,
                                    pickupLongitude: r.pickupLongitude,
                                    shopId: r.shopId,
                                    shopType: shopType,
                                    isLoggedIn: isLoggedIn,
                                    variant: variant,
                                    quantity: quantity
                                )
                            },
                            onCartClick: {
                                pushCartIfNeeded()
                            },
                            onNeedsAddress: {
                                openAddressForPendingCart()
                            },
                            onCancelNeedsAddress: {
                                homeViewModel.clearPendingCartAdd()
                            },
                            onClearCart: { homeViewModel.clearCart() },
                            shopType: r.shopType,
                            openingHour: r.openingHour,
                            closingHour: r.closingHour,
                            openingDays: r.openingDays,
                            openingSchedules: r.openingSchedules
                        )
                    case .cart:
                        CartScreen(
                            viewModel: homeViewModel,
                            onBack: { popNavigation() },
                            isLoggedIn: isLoggedIn,
                            onRequireLogin: onRequireLogin,
                            onPay: {
                                Task {
                                    let ok = await homeViewModel.runCheckoutFlow()
                                    if ok {
                                        navigationPath.removeAll()
                                        onCheckoutSuccess()
                                    }
                                }
                            }
                        )
                    }
                }
        }
        .onChange(of: navigationPath) { _, _ in
            syncMainTabBarHidden()
        }
        .onAppear {
            syncMainTabBarHidden()
        }
        .fullScreenCover(isPresented: $showCurrentAddress, onDismiss: {
            if !homeViewModel.hasValidDeliveryAddress {
                homeViewModel.clearPendingCartAdd()
                pendingOpenCartAfterAddress = false
            }
        }) {
            NavigationStack {
                CurrentAddressScreen(
                    placesAutocompleteRepository: placesAutocompleteRepository,
                    userAddressRepository: userAddressRepository,
                    httpClient: httpClient,
                    onDefaultAddressUpdated: {
                        Task {
                            let result = await homeViewModel.resumePendingCartAddIfPossible()
                            showCurrentAddress = false
                            if result == .success, pendingOpenCartAfterAddress {
                                pendingOpenCartAfterAddress = false
                                openCartAfterAddingFromProduct()
                            } else {
                                pendingOpenCartAfterAddress = false
                            }
                        }
                    },
                    isLoggedIn: isLoggedIn,
                    onRequireLogin: {
                        homeViewModel.clearPendingCartAdd()
                        pendingOpenCartAfterAddress = false
                        showCurrentAddress = false
                        onRequireLogin()
                    }
                )
            }
        }
        .alert("¿Cambiar de tienda?", isPresented: $showShopSwitchAlert) {
            Button("Cancelar", role: .cancel) {
                pendingProductRoute = nil
            }
            Button("Continuar", role: .destructive) {
                homeViewModel.clearCart()
                if let route = pendingProductRoute {
                    navigationPath.append(.product(route))
                }
                pendingProductRoute = nil
            }
        } message: {
            Text("Si entras a otra tienda perderás los productos de tu carrito actual.")
        }
    }

    private func syncMainTabBarHidden() {
        mainTabBarHidden = !navigationPath.isEmpty
    }

    private func popNavigation() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    private func pushCartIfNeeded() {
        ensureSingleCartOnTop()
    }

    private func openCartAfterAddingFromProduct() {
        ensureSingleCartOnTop()
    }

    private func ensureSingleCartOnTop() {
        navigationPath.removeAll { route in
            if case .cart = route { return true }
            return false
        }
        navigationPath.append(.cart)
    }

    private func openProduct(_ route: ProductDetailRoute) {
        if homeViewModel.needsShopSwitchConfirmationIfKnown(for: route.shopId) {
            pendingProductRoute = route
            showShopSwitchAlert = true
            return
        }
        navigationPath.append(.product(route))
    }

    private func openShopFromProduct(
        shopId: String,
        shopName: String,
        shopType: String?,
        pickupLatitude: Double?,
        pickupLongitude: Double?
    ) {
        let id = CartShopSwitchPolicy.normalized(shopId) ?? shopId
        if let idx = navigationPath.lastIndex(where: {
            if case .shop(let route) = $0 { return route.shopId == id }
            return false
        }) {
            navigationPath = Array(navigationPath.prefix(idx + 1))
            return
        }
        let place = homeViewModel.featuredPlaces.first { $0.id == id && !$0.isService }
            ?? promotionsViewModel.uiState.featuredPlaces.first { $0.id == id && !$0.isService }
        navigationPath.append(
            .shop(
                ShopDetailRoute(
                    shopId: id,
                    shopName: shopName.isEmpty ? (place?.name ?? "Tienda") : shopName,
                    pickupLatitude: pickupLatitude ?? place?.latitude,
                    pickupLongitude: pickupLongitude ?? place?.longitude,
                    shopType: shopType ?? place?.shopType,
                    openingHour: place?.openingHour,
                    closingHour: place?.closingHour,
                    openingDays: place?.openingDays ?? [],
                    openingSchedules: place?.openingSchedules ?? []
                )
            )
        )
    }

    @ViewBuilder
    private var promotionsRoot: some View {
        let s = promotionsViewModel.uiState
        ZStack {
            Color.white.ignoresSafeArea()

            if let err = s.errorMessage, !err.isEmpty, s.products.isEmpty, !s.isLoading {
                VStack(spacing: 16) {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        promotionsViewModel.loadPromotions()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PromotionsPalette.primary)
                }
            } else if s.isLoading, s.products.isEmpty {
                ProgressView()
                    .tint(PromotionsPalette.primary)
            } else if s.products.isEmpty {
                Text("No hay promociones disponibles por ahora.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                promotionsContent(products: s.products)
            }
        }
    }

    /// Same two-column grid as `ShopDetailScreen.shopProductsGrid` / product list in a shop.
    private func promotionsContent(products: [BestSellerProduct]) -> some View {
        let screenW = UIScreen.main.bounds.width
        let inner = screenW - HomeProductCardLayout.shopGridHorizontalPadding * 2
        let spacing: CGFloat = 12
        let cardW = (inner - spacing) / 2

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Promociones")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PromotionsPalette.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardW), spacing: spacing),
                        GridItem(.fixed(cardW), spacing: spacing),
                    ],
                    spacing: 12
                ) {
                    ForEach(products) { product in
                        Button {
                            openProduct(
                                ProductDetailRoute(
                                    bestSeller: product,
                                    featuredPlaces: promotionsViewModel.uiState.featuredPlaces
                                )
                            )
                        } label: {
                            UniversalProductCard(product: product, width: cardW)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HomeProductCardLayout.shopGridHorizontalPadding)
                .padding(.bottom, 12)

                Color.clear.frame(height: 100)
            }
        }
        .refreshable {
            await promotionsViewModel.refresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
