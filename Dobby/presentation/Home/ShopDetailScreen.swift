//
//  ShopDetailScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.ShopDetailScreen`.
//

import SwiftUI

/// Route payload for `NavigationStack` (Android: `DobbyScreens.shopDetail(id, name)`).
struct ShopDetailRoute: Hashable {
    let shopId: String
    let shopName: String
    var pickupLatitude: Double?
    var pickupLongitude: Double?
}

struct ShopDetailScreen: View {
    @State private var viewModel: ShopDetailViewModel

    let cartItemCount: Int
    let onBack: () -> Void
    let onProductTap: (ShopProduct, Bool) -> Void
    let onAddToCart: (ShopProduct, String?) -> AddToCartResult
    let onCartClick: () -> Void
    var onNeedsAddress: () -> Void = {}
    var onCancelNeedsAddress: () -> Void = {}

    @State private var showCarWashSingleProductAlert = false
    @State private var showAddressRequiredForCartAlert = false

    init(
        shopId: String,
        shopName: String,
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onProductTap: @escaping (ShopProduct, Bool) -> Void = { _, _ in },
        onAddToCart: @escaping (ShopProduct, String?) -> AddToCartResult = { _, _ in .success },
        onCartClick: @escaping () -> Void = {},
        onNeedsAddress: @escaping () -> Void = {},
        onCancelNeedsAddress: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onProductTap = onProductTap
        self.onAddToCart = onAddToCart
        self.onCartClick = onCartClick
        self.onNeedsAddress = onNeedsAddress
        self.onCancelNeedsAddress = onCancelNeedsAddress
        _viewModel = State(
            initialValue: ShopDetailViewModel(
                shopId: shopId,
                shopName: shopName,
                placesRepository: placesRepository,
                http: httpClient
            )
        )
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch (viewModel.uiState.isLoading, viewModel.uiState.errorMessage) {
            case (true, _):
                ProgressView()
                    .tint(DobbyBrandColor.primary)
            case (false, let err?) where !err.isEmpty:
                VStack(spacing: 16) {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        viewModel.loadProducts()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DobbyBrandColor.primary)
                }
            default:
                VStack(spacing: 0) {
                    ShopDetailSearchBar(query: Binding(
                        get: { viewModel.uiState.searchQuery },
                        set: { viewModel.onSearchQueryChange($0) }
                    ))

                    if viewModel.uiState.showShopClosedBanner {
                        ShopClosedBanner(reopensLabel: viewModel.uiState.shopReopensLabel)
                    }

                    ShopDetailCategoryRow(
                        selectedCategoryId: viewModel.uiState.selectedCategoryId,
                        onCategorySelected: { viewModel.onCategorySelected($0) }
                    )

                    if viewModel.uiState.filteredProducts.isEmpty {
                        Spacer()
                        Text(emptyProductsMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.uiState.filteredProducts) { product in
                                    ShopDetailProductCard(
                                        product: product,
                                        isProductAvailable: viewModel.uiState.isShopAvailableForOrders,
                                        onTap: { onProductTap(product, viewModel.uiState.isShopAvailableForOrders) },
                                        onAddTap: {
                                            guard viewModel.uiState.isShopAvailableForOrders else { return }
                                            switch onAddToCart(product, viewModel.uiState.shopType) {
                                            case .blockedCarWash:
                                                showCarWashSingleProductAlert = true
                                            case .needsAddress:
                                                showAddressRequiredForCartAlert = true
                                            case .success:
                                                break
                                            }
                                        }
                                    )
                                    .id(product.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.uiState.shopName.isEmpty ? "Productos" : viewModel.uiState.shopName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationBackButton(action: onBack)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCartClick) {
                    HomeCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
            .hideToolbarSharedBackgroundIfAvailable()
        }
        .alert("Un solo producto", isPresented: $showCarWashSingleProductAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(CartCarWashSingleProductPolicy.message)
        }
        .alert("Dirección requerida", isPresented: $showAddressRequiredForCartAlert) {
            Button("Cancelar", role: .cancel) {
                onCancelNeedsAddress()
            }
            Button("Agregar dirección") {
                onNeedsAddress()
            }
        } message: {
            Text("Agrega primero una dirección antes de comenzar a agregar productos al carrito.")
        }
    }

    private var emptyProductsMessage: String {
        let query = viewModel.uiState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return "Ningún producto coincide con la búsqueda"
        }
        if viewModel.uiState.selectedCategoryId != nil {
            return "No hay productos en esta categoría"
        }
        return "Este restaurante aún no tiene productos"
    }
}
