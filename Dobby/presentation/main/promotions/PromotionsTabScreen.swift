//
//  PromotionsTabScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.promotions.PromotionsTabScreen`.
//

import SwiftUI
import UIKit

private enum PromotionsPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
}

/// Routes for the promotions tab `NavigationStack` (product detail + cart).
private enum PromotionsStackRoute: Hashable {
    case product(ProductDetailRoute)
    case cart
}

struct PromotionsTabScreen: View {
    let placesRepository: PlacesRepository
    let favoritesStore: FavoritesStore
    @Bindable var promotionsViewModel: PromotionsTabViewModel
    @Bindable var homeViewModel: HomeTabViewModel
    @Binding var mainTabBarHidden: Bool

    @State private var navigationPath: [PromotionsStackRoute] = []

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
                                navigationPath.append(.cart)
                            },
                            onAddToCart: { quantity in
                                homeViewModel.addProductToCart(r, quantity: quantity)
                                navigationPath.append(.cart)
                            }
                        )
                    case .cart:
                        CartScreen(viewModel: homeViewModel, onBack: { popNavigation() }, onPay: {})
                    }
                }
        }
        .onChange(of: navigationPath) { _, _ in
            syncMainTabBarHidden()
        }
        .onAppear {
            syncMainTabBarHidden()
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
                            navigationPath.append(.product(ProductDetailRoute(bestSeller: product)))
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
