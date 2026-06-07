//
//  BestSellersScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.BestSellersScreen`.
//

import SwiftUI

struct BestSellersScreen: View {
    @State private var viewModel: BestSellersViewModel

    let cartItemCount: Int
    let onBack: () -> Void
    let onProductTap: (ShopProduct, Bool) -> Void
    let onAddToCart: (ShopProduct) -> Void
    let onCartClick: () -> Void

    init(
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
            initialValue: BestSellersViewModel(placesRepository: placesRepository, http: httpClient)
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
                        viewModel.loadBestSellers()
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
                                        isProductAvailable: viewModel.isProductAvailable(product),
                                        onTap: {
                                            onProductTap(product, viewModel.isProductAvailable(product))
                                        },
                                        onAddTap: {
                                            guard viewModel.isProductAvailable(product) else { return }
                                            onAddToCart(product)
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
        .navigationTitle("Más vendidos")
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
        return "No hay productos disponibles por ahora"
    }
}
