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
    let onAddToCart: (ShopProduct) -> Void
    let onCartClick: () -> Void

    init(
        shopId: String,
        shopName: String,
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onProductTap: @escaping (ShopProduct, Bool) -> Void = { _, _ in },
        onAddToCart: @escaping (ShopProduct) -> Void = { _ in },
        onCartClick: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onProductTap = onProductTap
        self.onAddToCart = onAddToCart
        self.onCartClick = onCartClick
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
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.uiState.filteredProducts) { product in
                                    ShopDetailProductCard(
                                        product: product,
                                        isProductAvailable: viewModel.uiState.isShopAvailableForOrders,
                                        onTap: { onProductTap(product, viewModel.uiState.isShopAvailableForOrders) },
                                        onAddTap: {
                                            guard viewModel.uiState.isShopAvailableForOrders else { return }
                                            onAddToCart(product)
                                        }
                                    )
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
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Atrás")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCartClick) {
                    HomeCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
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
