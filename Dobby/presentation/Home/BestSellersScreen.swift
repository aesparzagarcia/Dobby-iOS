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
    let onAddToCart: (ShopProduct) -> AddToCartResult
    let onCartClick: () -> Void
    var onNeedsAddress: () -> Void = {}
    var onCancelNeedsAddress: () -> Void = {}

    @State private var showCarWashSingleProductAlert = false
    @State private var showAddressRequiredForCartAlert = false

    init(
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        initialFeaturedPlaces: [FeaturedPlace] = [],
        onBack: @escaping () -> Void = {},
        onProductTap: @escaping (ShopProduct, Bool) -> Void = { _, _ in },
        onAddToCart: @escaping (ShopProduct) -> AddToCartResult = { _ in .success },
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
            initialValue: BestSellersViewModel(
                placesRepository: placesRepository,
                http: httpClient,
                initialFeaturedPlaces: initialFeaturedPlaces
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
                                            switch onAddToCart(product) {
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
        .navigationTitle("Más vendidos")
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
        return "No hay productos disponibles por ahora"
    }
}
