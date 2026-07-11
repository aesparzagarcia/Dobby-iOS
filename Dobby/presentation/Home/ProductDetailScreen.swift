//
//  ProductDetailScreen.swift
//  Dobby
//

import SwiftUI

private enum ProductDetailPalette {
    static let mutedText = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let ratingPillBg = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let quantityPillBg = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let closedGray = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let promoOrange = Color(red: 1, green: 0.54, blue: 0.24)
    static let divider = Color(red: 0.91, green: 0.91, blue: 0.93)
}

private let heroImagePadding: CGFloat = 24
private let cardOverlap: CGFloat = 24

struct ProductDetailScreen: View {
    let product: ProductDetailRoute
    let placesRepository: PlacesRepository
    var tokenRefresh: ConsumerTokenRefreshService? = nil
    let favoritesStore: FavoritesStore
    let cartItemCount: Int
    let userLatitude: Double?
    let userLongitude: Double?
    let onBack: () -> Void
    let onCartClick: () -> Void
    let onAddToCart: (Int, ProductDetail?) -> Void

    @State private var quantity = 1
    @State private var loadedDetail: ProductDetail?
    @State private var detailFetchFinished = false
    @State private var imagePage = 0

    init(
        product: ProductDetailRoute,
        placesRepository: PlacesRepository,
        tokenRefresh: ConsumerTokenRefreshService? = nil,
        favoritesStore: FavoritesStore,
        cartItemCount: Int,
        userLatitude: Double? = nil,
        userLongitude: Double? = nil,
        onBack: @escaping () -> Void,
        onCartClick: @escaping () -> Void,
        onAddToCart: @escaping (Int, ProductDetail?) -> Void
    ) {
        self.product = product
        self.placesRepository = placesRepository
        self.tokenRefresh = tokenRefresh
        self.favoritesStore = favoritesStore
        self.cartItemCount = cartItemCount
        self.userLatitude = userLatitude
        self.userLongitude = userLongitude
        self.onBack = onBack
        self.onCartClick = onCartClick
        self.onAddToCart = onAddToCart
    }

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

    private var displayRatingCount: Int {
        loadedDetail?.ratingCount ?? product.ratingCount
    }

    private var showInitialLoading: Bool {
        product.isPromotionPushStub && !detailFetchFinished && loadedDetail == nil
    }

    private var imageUrls: [String] {
        if let detail = loadedDetail, !detail.imageUrls.isEmpty {
            return detail.imageUrls
        }
        if let url = product.imageUrl { return [url] }
        return []
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

    private var lineTotal: Double {
        discountedPrice * Double(quantity)
    }

    private var deliveryEtaLabel: String {
        DeliveryEtaEstimator.estimateLabelForPickup(
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            pickupLatitude: product.pickupLatitude,
            pickupLongitude: product.pickupLongitude
        )
    }

    private var displayDescription: String? {
        let fromApi = loadedDetail?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromRoute = product.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromApi, !fromApi.isEmpty { return fromApi }
        if let fromRoute, !fromRoute.isEmpty { return fromRoute }
        return nil
    }

    private var canAddToCart: Bool {
        quantity > 0 && product.isShopAvailableForOrders && (loadedDetail != nil || !product.isPromotionPushStub)
    }

    private var isFavorite: Bool {
        favoritesStore.isFavorite(productId: product.id)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            if showInitialLoading {
                ProgressView()
                    .tint(DobbyBrandColor.primary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                        infoCard
                            .offset(y: -cardOverlap)
                            .padding(.bottom, 100)
                    }
                }
            }

            bottomActionBar
        }
        .navigationBarHidden(true)
        .task(id: product.id) {
            await loadProductDetail()
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            TabView(selection: $imagePage) {
                if imageUrls.isEmpty {
                    heroImagePage(urlString: nil)
                        .tag(0)
                } else {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                        heroImagePage(urlString: urlString)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if imageUrls.count > 1 {
                HStack(spacing: 6) {
                    ForEach(imageUrls.indices, id: \.self) { index in
                        Circle()
                            .fill(index == imagePage ? Color.white : Color.white.opacity(0.55))
                            .frame(width: index == imagePage ? 8 : 6, height: index == imagePage ? 8 : 6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 36)
            }

            HStack {
                overlayIconButton(systemName: "chevron.left", action: onBack)
                Spacer()
                Button(action: onCartClick) {
                    HomeCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            overlayIconButton(
                systemName: isFavorite ? "heart.fill" : "heart",
                tint: isFavorite ? DobbyBrandColor.primary : .primary,
                action: { favoritesStore.toggle(from: displayProduct) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 16)
            .padding(.bottom, cardOverlap + 12)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func heroImagePage(urlString: String?) -> some View {
        ZStack {
            Color.white
            LoadingRemoteImage(
                urlString: urlString,
                contentMode: .fit,
                placeholderBackground: .white
            ) {
                heroImageMonogram
            }
            .padding(heroImagePadding)
        }
    }

    private var heroImageMonogram: some View {
        Text(String(displayProduct.name.prefix(1)).uppercased())
            .font(.system(size: 72, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(displayProduct.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HomeRatingDisplay(rate: displayProduct.rate, ratingCount: displayRatingCount)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ProductDetailPalette.ratingPillBg)
                    .clipShape(Capsule())
            }

            if let desc = displayDescription {
                Text(desc)
                    .font(.body)
                    .foregroundStyle(ProductDetailPalette.mutedText)
                    .padding(.top, 10)
            }

            priceBlock
                .padding(.top, 14)

            Divider()
                .overlay(ProductDetailPalette.divider)
                .padding(.vertical, 12)

            statusRow
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var priceBlock: some View {
        Group {
            if showPromotion {
                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", discountedPrice))
                        .font(.title3.weight(.bold))
                    HStack(spacing: 4) {
                        Text("-\(validDiscount)%")
                            .font(.caption2.weight(.bold))
                        Text(String(format: "$%.2f", displayProduct.price))
                            .font(.caption2)
                            .strikethrough()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ProductDetailPalette.promoOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            } else {
                Text(String(format: "$%.2f", displayProduct.price))
                    .font(.title3.weight(.bold))
            }
        }
        .foregroundStyle(.primary)
    }

    private var statusRow: some View {
        let statusColor = product.isShopAvailableForOrders ? DobbyBrandColor.primary : ProductDetailPalette.closedGray
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text(deliveryEtaLabel)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(DobbyBrandColor.primary)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(DobbyBrandColor.primary.opacity(0.25))
                .frame(width: 1, height: 18)

            HStack(spacing: 6) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 14))
                Text(product.isShopAvailableForOrders ? "Disponible" : "No disponible")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity)
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DobbyBrandColor.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(quantity <= 1)

                    Text("\(quantity)")
                        .font(.title3.monospacedDigit().weight(.medium))
                        .frame(minWidth: 28)

                    Button { quantity += 1 } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DobbyBrandColor.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(ProductDetailPalette.quantityPillBg)
                .clipShape(Capsule())

                Button {
                    onAddToCart(quantity, loadedDetail)
                    quantity = 1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16))
                        Text("Añadir al carrito")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        Text(String(format: "$%.2f", lineTotal))
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(canAddToCart ? DobbyBrandColor.primary : DobbyBrandColor.primary.opacity(0.45))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canAddToCart)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }

    private func overlayIconButton(
        systemName: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
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
}
