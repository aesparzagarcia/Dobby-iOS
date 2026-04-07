//
//  HomeTabScreen.swift
//  Dobby
//

import SwiftUI
import UIKit

private enum HomePalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let searchBackground = Color(red: 0.93, green: 0.90, blue: 0.98)
    static let title = primary
}

/// Single navigation stack so Back always pops one level (shop → product → cart), never jumps to home.
private enum HomeStackRoute: Hashable {
    case shop(ShopDetailRoute)
    case product(ProductDetailRoute)
    case cart
}

struct HomeTabScreen: View {
    @Bindable var viewModel: HomeTabViewModel
    let placesRepository: PlacesRepository
    let favoritesStore: FavoritesStore
    let userAddressRepository: UserAddressRepository
    let placesAutocompleteRepository: PlacesAutocompleteRepository
    let httpClient: DobbyHTTPClient
    /// When `true`, `MainTabView` hides the bottom floating tab bar (e.g. shop detail is visible).
    @Binding var mainTabBarHidden: Bool

    private let searchHints = ["tacos", "cerveza", "la huerta de vega", "pizza", "café", "restaurantes"]
    @State private var hintIndex = 0
    @State private var showCurrentAddress = false
    @State private var navigationPath: [HomeStackRoute] = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $navigationPath) {
            homeContent
                .navigationDestination(for: HomeStackRoute.self) { route in
                    switch route {
                    case .shop(let r):
                        ShopDetailScreen(
                            shopId: r.shopId,
                            shopName: r.shopName,
                            placesRepository: placesRepository,
                            httpClient: httpClient,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onProductTap: { product in
                                navigationPath.append(.product(ProductDetailRoute(shopProduct: product)))
                            },
                            onCartClick: {
                                navigationPath.append(.cart)
                            }
                        )
                    case .product(let r):
                        ProductDetailScreen(
                            product: r,
                            placesRepository: placesRepository,
                            favoritesStore: favoritesStore,
                            cartItemCount: viewModel.cartItemCount,
                            onBack: { popNavigation() },
                            onCartClick: {
                                navigationPath.append(.cart)
                            },
                            onAddToCart: { quantity in
                                viewModel.addProductToCart(r, quantity: quantity)
                                navigationPath.append(.cart)
                            }
                        )
                    case .cart:
                        CartScreen(viewModel: viewModel, onBack: { popNavigation() }, onPay: {})
                    }
                }
        }
        .onChange(of: navigationPath) { _, _ in
            syncMainTabBarHiddenWithNavigation()
        }
        .onAppear {
            syncMainTabBarHiddenWithNavigation()
        }
    }

    private func syncMainTabBarHiddenWithNavigation() {
        mainTabBarHidden = !navigationPath.isEmpty
    }

    private func popNavigation() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    private var homeContent: some View {
        Group {
            if let err = viewModel.errorMessage, viewModel.featuredPlaces.isEmpty, !viewModel.isLoading {
                VStack(spacing: 16) {
                    Text(err)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        viewModel.loadHome()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomePalette.primary)
                }
            } else if viewModel.isLoading && viewModel.featuredPlaces.isEmpty {
                ProgressView()
                    .tint(HomePalette.primary)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            viewModel.loadInitial()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                hintIndex = (hintIndex + 1) % searchHints.count
            }
        }
        .fullScreenCover(isPresented: $showCurrentAddress) {
            NavigationStack {
                CurrentAddressScreen(
                    placesAutocompleteRepository: placesAutocompleteRepository,
                    userAddressRepository: userAddressRepository,
                    httpClient: httpClient,
                    onDefaultAddressUpdated: { viewModel.loadAddresses() }
                )
            }
        }
    }

    private func onFeaturedPlaceTap(_ place: FeaturedPlace) {
        if place.isService {
            return
        }
        navigationPath.append(.shop(ShopDetailRoute(shopId: place.id, shopName: place.name)))
    }

    private var content: some View {
        let screenW = UIScreen.main.bounds.width
        let cardWidth = max(120, (screenW - 56) / 2)
        let productWidth = HomeProductCardLayout.cardWidth(screenWidth: screenW)

        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredPlaces = viewModel.featuredPlaces.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        let filteredProducts = viewModel.bestSellerProducts.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        let restaurantsOnly = filteredPlaces.filter { !$0.isService }
        let servicesOnly = filteredPlaces.filter(\.isService)

        return ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let warn = viewModel.warningMessage {
                        warningBanner(warn)
                    }

                    headerBlock

                    sectionTitle("Destacado")

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(filteredPlaces) { place in
                                FeaturedPlaceCard(place: place, width: cardWidth, onTap: { onFeaturedPlaceTap(place) })
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !filteredProducts.isEmpty {
                        sectionTitle("Más vendidos")
                            .padding(.top, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(filteredProducts) { product in
                                    Button {
                                        navigationPath.append(.product(ProductDetailRoute(bestSeller: product)))
                                    } label: {
                                        UniversalProductCard(product: product, width: productWidth)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !query.isEmpty && filteredPlaces.isEmpty && filteredProducts.isEmpty {
                        Text("Sin resultados para \"\(query)\"")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    if !viewModel.ads.isEmpty {
                        AdsCarousel(ads: viewModel.ads)
                            .padding(.vertical, 12)
                    }

                    if !restaurantsOnly.isEmpty {
                        sectionTitle("Restaurantes")
                            .padding(.top, 8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(restaurantsOnly) { place in
                                    FeaturedPlaceCard(place: place, width: cardWidth, onTap: { onFeaturedPlaceTap(place) })
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !servicesOnly.isEmpty {
                        sectionTitle("Servicios")
                            .padding(.top, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(servicesOnly) { place in
                                    FeaturedPlaceCard(place: place, width: cardWidth, onTap: { onFeaturedPlaceTap(place) })
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }

            Button {
                navigationPath.append(.cart)
            } label: {
                CartIconBadge(count: viewModel.cartItemCount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Carrito")
            .padding(.trailing, 16)
            .padding(.top, 4)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    showCurrentAddress = true
                } label: {
                    Text(viewModel.addressLabel ?? "Casa")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(HomePalette.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Button {
                    showCurrentAddress = true
                } label: {
                    Text(viewModel.address ?? "Añade tu dirección")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.address != nil ? Color.primary : Color.secondary)
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 56)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    "",
                    text: $viewModel.searchQuery,
                    prompt: Text("Busca \"\(searchHints[hintIndex])\"")
                        .foregroundStyle(Color.secondary)
                )
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { searchFocused = false }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(HomePalette.searchBackground)
            .clipShape(Capsule())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(HomePalette.title)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    private func warningBanner(_ msg: String) -> some View {
        HStack {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button("Cerrar") {
                viewModel.clearWarningMessage()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Cart

private struct CartIconBadge: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "cart.fill")
                .font(.title2)
                .foregroundStyle(.primary)
                .padding(8)
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(HomePalette.primary)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Featured

private struct FeaturedPlaceCard: View {
    let place: FeaturedPlace
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                    if let url = place.imageUrl.flatMap(URL.init(string:)) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Text(String(place.name.prefix(1)).uppercased())
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(String(place.name.prefix(1)).uppercased())
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: width, height: width * 3 / 4)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(place.typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ads

private struct AdsCarousel: View {
    let ads: [Ad]
    @State private var index = 0

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let pageW = max(200, screenW - 32)

        TabView(selection: $index) {
            ForEach(Array(ads.enumerated()), id: \.element.id) { i, ad in
                adCard(ad)
                    .frame(width: pageW)
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .task {
            guard ads.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                index = (index + 1) % ads.count
            }
        }
    }

    private func adCard(_ ad: Ad) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
            if let url = ad.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Text(String(ad.name.prefix(1)).uppercased())
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(String(ad.name.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
