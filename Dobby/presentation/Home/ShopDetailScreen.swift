//
//  ShopDetailScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.ShopDetailScreen`.
//

import SwiftUI
import UIKit

private enum ShopDetailPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
}

/// Route payload for `NavigationStack` (Android: `DobbyScreens.shopDetail(id, name)`).
struct ShopDetailRoute: Hashable {
    let shopId: String
    let shopName: String
}

struct ShopDetailScreen: View {
    @State private var viewModel: ShopDetailViewModel

    let cartItemCount: Int
    let onBack: () -> Void
    let onProductTap: (ShopProduct) -> Void
    let onCartClick: () -> Void

    init(
        shopId: String,
        shopName: String,
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onProductTap: @escaping (ShopProduct) -> Void = { _ in },
        onCartClick: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onProductTap = onProductTap
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
            Color(red: 0.97, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            switch (viewModel.uiState.isLoading, viewModel.uiState.errorMessage) {
            case (true, _):
                ProgressView()
                    .tint(ShopDetailPalette.primary)
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
                    .tint(ShopDetailPalette.primary)
                }
            default:
                ScrollView {
                    shopProductsGrid
                }
            }
        }
        .navigationTitle(viewModel.uiState.shopName.isEmpty ? "Productos" : viewModel.uiState.shopName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Atrás")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCartClick) {
                    ShopDetailCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var shopProductsGrid: some View {
        let screenW = UIScreen.main.bounds.width
        let inner = screenW - HomeProductCardLayout.shopGridHorizontalPadding * 2
        let spacing: CGFloat = 12
        /// Exactly two products per row; each tile shares the row width evenly.
        let cardW = (inner - spacing) / 2

        LazyVGrid(
            columns: [
                GridItem(.fixed(cardW), spacing: spacing),
                GridItem(.fixed(cardW), spacing: spacing),
            ],
            spacing: 12
        ) {
            ForEach(viewModel.uiState.products) { product in
                ShopProductGridCard(product: product, width: cardW) {
                    onProductTap(product)
                }
            }
        }
        .padding(.horizontal, HomeProductCardLayout.shopGridHorizontalPadding)
        .padding(.vertical, 12)
    }
}

// MARK: - Cart badge (parity with Android `CartIconBadge` on shop detail)

private struct ShopDetailCartIconBadge: View {
    let count: Int

    /// ~10% under `.title2` (~22pt) for a lighter header affordance.
    private let iconSize: CGFloat = 20

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "cart.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(ShopDetailPalette.primary)
                    .clipShape(Circle())
                    .offset(x: 5, y: -3)
            }
        }
    }
}

// MARK: - Product card (parity with Android `UniversalProductCard` + `ShopProduct`)

private struct ShopProductGridCard: View {
    let product: ShopProduct
    let width: CGFloat
    let onTap: () -> Void

    private let cardRadius: CGFloat = 14

    private var validDiscount: Int {
        max(0, min(100, product.discount))
    }

    private var showPromotion: Bool {
        product.hasPromotion && validDiscount > 0
    }

    private var discountedPrice: Double {
        showPromotion ? product.price * (1 - Double(validDiscount) / 100) : product.price
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    imageBlock
                        .frame(width: width, height: width)
                        .clipped()

                    if showPromotion {
                        shopProductCardDiscountLabel(
                            validDiscount: validDiscount,
                            originalPrice: product.price
                        )
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: width, height: width)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "$%.2f", discountedPrice))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(product.name)
                        .font(.footnote)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(alignment: .center, spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ShopDetailPalette.primary)
                        Text(String(format: "%.1f", product.rate))
                            .font(.caption2)
                            .foregroundStyle(Color(white: 0.25))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageBlock: some View {
        ZStack {
            Color(.systemGray5)
            if let url = product.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: width)
                            .clipped()
                    case .failure:
                        placeholderMonogram
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderMonogram
                    }
                }
            } else {
                placeholderMonogram
            }
        }
    }

    private var placeholderMonogram: some View {
        Text(String(product.name.prefix(1)).uppercased())
            .font(.title2.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

@ViewBuilder
private func shopProductCardDiscountLabel(validDiscount: Int, originalPrice: Double) -> some View {
    HStack(spacing: 0) {
        HStack(spacing: 4) {
            Text("-\(validDiscount)%")
                .font(.caption2.weight(.bold))
            Text(String(format: "$%.2f", originalPrice))
                .font(.caption2)
                .strikethrough()
        }
        .foregroundStyle(.primary)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(Color(red: 1, green: 0.89, blue: 0.3))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 10,
                topTrailingRadius: 10,
                style: .continuous
            )
        )
        Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
