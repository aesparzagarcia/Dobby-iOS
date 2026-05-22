//
//  ProductDetailScreen.swift
//  Dobby
//

import SwiftUI

private enum ProductDetailPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let screenBackground = Color(red: 0.97, green: 0.96, blue: 0.98)
}

struct ProductDetailScreen: View {
    let product: ProductDetailRoute
    let placesRepository: PlacesRepository
    var tokenRefresh: ConsumerTokenRefreshService? = nil
    let favoritesStore: FavoritesStore
    let cartItemCount: Int
    /// Pops one level on the home `NavigationStack` (e.g. back to restaurant). Prefer this over `dismiss()` with `navigationPath`.
    let onBack: () -> Void
    let onCartClick: () -> Void
    let onAddToCart: (Int, ProductDetail?) -> Void

    @State private var quantity = 0
    /// Loaded from `GET app/products/:id` (lists like home/promotions omit description).
    @State private var loadedDetail: ProductDetail?
    @State private var detailFetchFinished = false

    /// Prefer API detail (e.g. promotion push only sends `product_id`).
    private var displayProduct: ProductDetailRoute {
        if let detail = loadedDetail {
            return ProductDetailRoute(
                detail: detail,
                pickupLatitude: product.pickupLatitude,
                pickupLongitude: product.pickupLongitude,
                shopId: product.shopId
            )
        }
        return product
    }

    private var validDiscount: Int {
        max(0, min(100, displayProduct.discount))
    }

    private var showPromotion: Bool {
        displayProduct.hasPromotion && validDiscount > 0
    }

    private var discountedPrice: Double {
        showPromotion ? displayProduct.price * (1 - Double(validDiscount) / 100) : displayProduct.price
    }

    private var showDetailLoading: Bool {
        !detailFetchFinished && loadedDetail == nil
    }

    private var canAddToCart: Bool {
        quantity > 0 && (loadedDetail != nil || !product.isPromotionPushStub)
    }

    /// Unit price × current quantity (updates with + / −).
    private var lineTotal: Double {
        discountedPrice * Double(quantity)
    }

    private var lineTotalFormatted: String {
        String(format: "$%.2f", lineTotal)
    }

    private var displayDescription: String? {
        let fromApi = loadedDetail?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromRoute = product.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromApi, !fromApi.isEmpty { return fromApi }
        if let fromRoute, !fromRoute.isEmpty { return fromRoute }
        return nil
    }

    private var showDescriptionLoading: Bool {
        !detailFetchFinished && displayDescription == nil
    }

    private var heroImageURL: URL? {
        if let first = loadedDetail?.imageUrls.first, let u = URL(string: first) { return u }
        return product.imageUrl.flatMap(URL.init(string:))
    }

    private var isFavorite: Bool {
        favoritesStore.isFavorite(productId: product.id)
    }

    var body: some View {
        ZStack {
            ProductDetailPalette.screenBackground
                .ignoresSafeArea()

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    productHeroImage

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            if showDetailLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(displayProduct.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                favoritesStore.toggle(from: displayProduct)
                            } label: {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundStyle(isFavorite ? ProductDetailPalette.primary : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
                        }

                        priceBlock

                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.subheadline)
                                .foregroundStyle(ProductDetailPalette.primary)
                            Text(String(format: "%.1f", displayProduct.rate))
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.35))
                        }

                        if showDescriptionLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let desc = displayDescription {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Sin descripción disponible.")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .navigationTitle(displayProduct.name)
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
                    ProductDetailCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
        }
        .task(id: product.id) {
            await loadProductDetail()
        }
    }

    private func loadProductDetail() async {
        loadedDetail = nil
        detailFetchFinished = false
        if product.isPromotionPushStub, let tokenRefresh {
            await tokenRefresh.refreshAccessTokenOnForeground()
        }
        for attempt in 0 ..< 6 {
            if Task.isCancelled { return }
            switch await placesRepository.getProduct(id: product.id) {
            case .success(let detail):
                loadedDetail = detail
                detailFetchFinished = true
                return
            case .failure:
                if attempt < 5 {
                    if let tokenRefresh {
                        await tokenRefresh.refreshAccessTokenOnForeground()
                    }
                    try? await Task.sleep(nanoseconds: UInt64(300_000_000 * UInt64(attempt + 1)))
                }
            }
        }
        detailFetchFinished = true
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showDetailLoading {
                ProgressView()
            } else if showPromotion {
                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", discountedPrice))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(String(format: "$%.2f", displayProduct.price))
                        .font(.subheadline)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                    Text("-\(validDiscount)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 1, green: 0.89, blue: 0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            } else {
                Text(String(format: "$%.2f", displayProduct.price))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var productHeroImage: some View {
        Group {
            if let url = heroImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            // Constrain intrinsic image width so wide photos do not expand ScrollView content.
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
        .background(Color(.systemGray5))
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Text(String(displayProduct.name.prefix(1)).uppercased())
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    if quantity > 0 {
                        Button {
                            quantity -= 1
                        } label: {
                            Image(systemName: "minus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(ProductDetailPalette.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Disminuir cantidad")
                    }

                    Text("\(quantity)")
                        .font(.title3.monospacedDigit().weight(.medium))
                        .frame(minWidth: 28)
                        .foregroundStyle(.primary)

                    Button {
                        quantity += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(ProductDetailPalette.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Aumentar cantidad")
                }

                Button {
                    onAddToCart(quantity, loadedDetail)
                    quantity = 0
                } label: {
                    VStack(spacing: 4) {
                        Text("Añadir al carrito")
                            .font(.subheadline.weight(.semibold))
                        Text(lineTotalFormatted)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(ProductDetailPalette.primary)
                .disabled(!canAddToCart)
                .opacity(canAddToCart ? 1 : 0.45)
                .accessibilityLabel("Añadir al carrito, total \(lineTotalFormatted)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Cart badge (matches shop detail toolbar)

private struct ProductDetailCartIconBadge: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "cart.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(ProductDetailPalette.primary)
                    .clipShape(Circle())
                    .offset(x: 5, y: -3)
            }
        }
    }
}
