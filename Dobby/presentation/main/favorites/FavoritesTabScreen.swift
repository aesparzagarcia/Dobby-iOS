//
//  FavoritesTabScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.favorites.FavoritesTabScreen`.
//

import SwiftUI
import UIKit

private enum FavoritesPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
}

private enum FavoritesStackRoute: Hashable {
    case product(ProductDetailRoute)
    case cart
}

struct FavoritesTabScreen: View {
    let placesRepository: PlacesRepository
    @Bindable var favoritesStore: FavoritesStore
    @Bindable var homeViewModel: HomeTabViewModel
    @Binding var mainTabBarHidden: Bool
    let onCheckoutSuccess: () -> Void

    @State private var navigationPath: [FavoritesStackRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            favoritesRoot
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: FavoritesStackRoute.self) { route in
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
                        CartScreen(
                            viewModel: homeViewModel,
                            onBack: { popNavigation() },
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
            favoritesStore.refresh()
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
    private var favoritesRoot: some View {
        let list = favoritesStore.products
        ZStack {
            Color.white.ignoresSafeArea()

            if list.isEmpty {
                VStack(spacing: 12) {
                    Text("Favoritos")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FavoritesPalette.primary)
                    Text("Aún no has guardado productos en favoritos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                favoritesContent(products: list)
            }
        }
    }

    /// Same two-column grid as `ShopDetailScreen.shopProductsGrid` / product list in a shop.
    private func favoritesContent(products: [FavoriteProduct]) -> some View {
        let screenW = UIScreen.main.bounds.width
        let inner = screenW - HomeProductCardLayout.shopGridHorizontalPadding * 2
        let spacing: CGFloat = 12
        let cardW = (inner - spacing) / 2

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Favoritos")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FavoritesPalette.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardW), spacing: spacing),
                        GridItem(.fixed(cardW), spacing: spacing),
                    ],
                    spacing: 12
                ) {
                    ForEach(products) { fav in
                        Button {
                            navigationPath.append(.product(ProductDetailRoute(favorite: fav)))
                        } label: {
                            UniversalProductCard(product: fav.toBestSellerProduct(), width: cardW)
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
            favoritesStore.refresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
