//
//  HomeTabViewModel.swift
//  Dobby
//

import Foundation

@MainActor
@Observable
final class HomeTabViewModel {
    private let placesRepository: PlacesRepository
    private let adsRepository: AdsRepository
    private let userAddressRepository: UserAddressRepository
    private let http: DobbyHTTPClient
    private let cartLocalStore: CartLocalStore

    var featuredPlaces: [FeaturedPlace] = []
    var bestSellerProducts: [BestSellerProduct] = []
    var ads: [Ad] = []
    var searchQuery = ""
    var addressLabel: String?
    var address: String?
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var warningMessage: String?
    /// Local cart lines (placeholder until cart API exists on iOS).
    var cartLines: [CartLineItem] = []

    var cartItemCount: Int {
        cartLines.reduce(0) { $0 + $1.quantity }
    }

    var cartTotal: Double {
        cartLines.reduce(0) { $0 + $1.lineTotal }
    }

    func addProductToCart(_ product: ProductDetailRoute, quantity: Int) {
        guard quantity > 0 else { return }
        let validDiscount = max(0, min(100, product.discount))
        let showPromotion = product.hasPromotion && validDiscount > 0
        let unitAfterDiscount = product.unitPriceAfterDiscount
        let list = product.price

        if let i = cartLines.firstIndex(where: { $0.productId == product.id }) {
            cartLines[i].quantity += quantity
        } else {
            cartLines.append(
                CartLineItem(
                    productId: product.id,
                    name: product.name,
                    imageUrl: product.imageUrl,
                    quantity: quantity,
                    unitPrice: unitAfterDiscount,
                    listUnitPrice: list,
                    hasPromotion: showPromotion,
                    discount: validDiscount
                )
            )
        }
        cartLocalStore.persist(lines: cartLines)
    }

    func removeCartLine(productId: String) {
        cartLines.removeAll { $0.productId == productId }
        cartLocalStore.persist(lines: cartLines)
    }

    init(
        placesRepository: PlacesRepository,
        adsRepository: AdsRepository,
        userAddressRepository: UserAddressRepository,
        http: DobbyHTTPClient,
        cartLocalStore: CartLocalStore
    ) {
        self.placesRepository = placesRepository
        self.adsRepository = adsRepository
        self.userAddressRepository = userAddressRepository
        self.http = http
        self.cartLocalStore = cartLocalStore
        cartLines = cartLocalStore.loadLines()
    }

    func onSearchQueryChange(_ q: String) {
        searchQuery = q
    }

    func clearWarningMessage() {
        warningMessage = nil
    }

    func loadInitial() {
        isLoading = true
        errorMessage = nil
        warningMessage = nil
        loadAddresses()
        Task {
            switch await placesRepository.getHome() {
            case .success(let data):
                featuredPlaces = data.featuredPlaces
                bestSellerProducts = data.bestSellerProducts
                isLoading = false
            case .failure(let e):
                isLoading = false
                if !e.shouldSuppressUserMessage {
                    errorMessage = message(for: e)
                }
            }
            await loadAds()
        }
    }

    func loadHome() {
        Task {
            isLoading = true
            errorMessage = nil
            warningMessage = nil
            switch await placesRepository.getHome() {
            case .success(let data):
                featuredPlaces = data.featuredPlaces
                bestSellerProducts = data.bestSellerProducts
                isLoading = false
            case .failure(let e):
                isLoading = false
                if !e.shouldSuppressUserMessage {
                    errorMessage = message(for: e)
                }
            }
        }
    }

    func loadAddresses() {
        Task {
            switch await userAddressRepository.getAddresses() {
            case .success(let list):
                let chosen = list.first(where: \.isDefault) ?? list.first
                addressLabel = chosen?.label ?? "Casa"
                if let raw = chosen?.address {
                    address = raw.addressWithColonyOnly()
                } else {
                    address = nil
                }
            case .failure(let e):
                addressLabel = "Casa"
                address = nil
                guard !e.shouldSuppressUserMessage else { return }
                if case .http(let he) = e {
                    warningMessage = http.userFacingMessage(from: he)
                } else {
                    warningMessage = "Inicia sesión para ver tus direcciones."
                }
            }
        }
    }

    private func loadAds() async {
        switch await adsRepository.getAds() {
        case .success(let list):
            ads = list
        case .failure(let e):
            ads = []
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        async let homeTask: Void = refreshHome()
        async let addrTask: Void = refreshAddresses()
        async let adsTask: Void = refreshAds()
        _ = await (homeTask, addrTask, adsTask)
        isRefreshing = false
    }

    private func refreshHome() async {
        switch await placesRepository.getHome() {
        case .success(let data):
            featuredPlaces = data.featuredPlaces
            bestSellerProducts = data.bestSellerProducts
            errorMessage = nil
        case .failure(let e):
            if !e.shouldSuppressUserMessage {
                errorMessage = message(for: e)
            }
        }
    }

    private func refreshAddresses() async {
        switch await userAddressRepository.getAddresses() {
        case .success(let list):
            let chosen = list.first(where: \.isDefault) ?? list.first
            addressLabel = chosen?.label ?? "Casa"
            if let raw = chosen?.address {
                address = raw.addressWithColonyOnly()
            } else {
                address = nil
            }
        case .failure(let e):
            addressLabel = "Casa"
            address = nil
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    private func refreshAds() async {
        switch await adsRepository.getAds() {
        case .success(let list):
            ads = list
        case .failure(let e):
            ads = []
            guard !e.shouldSuppressUserMessage else { return }
            if case .http(let he) = e {
                warningMessage = http.userFacingMessage(from: he)
            }
        }
    }

    private func message(for error: HomeRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let e):
            return http.userFacingMessage(from: e)
        }
    }
}
