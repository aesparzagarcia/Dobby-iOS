//
//  BestSellersViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.BestSellersViewModel`.
//

import Foundation

struct BestSellersUiState: Equatable {
    var products: [ShopProduct] = []
    var featuredPlaces: [FeaturedPlace] = []
    var searchQuery: String = ""
    var selectedCategoryId: String?
    var isLoading: Bool = false
    var errorMessage: String?

    var filteredProducts: [ShopProduct] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return products.filter { product in
            ProductCategory.matchesFilter(productCategory: product.category, filterId: selectedCategoryId)
                && (query.isEmpty || product.name.localizedCaseInsensitiveContains(query))
        }
    }
}

@MainActor
@Observable
final class BestSellersViewModel {
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState: BestSellersUiState

    init(placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.placesRepository = placesRepository
        self.http = http
        uiState = BestSellersUiState(isLoading: true)
        Task { await loadBestSellersAsync() }
    }

    func loadBestSellers() {
        Task { await loadBestSellersAsync() }
    }

    func onSearchQueryChange(_ query: String) {
        uiState.searchQuery = query
    }

    func onCategorySelected(_ categoryId: String?) {
        uiState.selectedCategoryId = categoryId
    }

    func isProductAvailable(_ product: ShopProduct) -> Bool {
        HomeShopHours.isProductShopAvailableForOrders(
            shopId: product.shopId,
            featuredPlaces: uiState.featuredPlaces
        )
    }

    func pickupCoordinates(for shopId: String?) -> (Double?, Double?) {
        guard let id = shopId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return (nil, nil)
        }
        let place = uiState.featuredPlaces.first { $0.id == id && !$0.isService }
        return (place?.latitude, place?.longitude)
    }

    private func loadBestSellersAsync() async {
        uiState.errorMessage = nil
        uiState.isLoading = true

        async let productsResult = placesRepository.getBestSellers()
        async let homeResult = placesRepository.getHome()

        switch await productsResult {
        case .success(let products):
            let featuredPlaces: [FeaturedPlace]
            if case .success(let home) = await homeResult {
                featuredPlaces = home.featuredPlaces
            } else {
                featuredPlaces = uiState.featuredPlaces
            }
            uiState = BestSellersUiState(
                products: HomeShopHours.sortShopProductsByShopAvailability(
                    products: products,
                    featuredPlaces: featuredPlaces
                ),
                featuredPlaces: featuredPlaces,
                searchQuery: uiState.searchQuery,
                selectedCategoryId: uiState.selectedCategoryId,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = BestSellersUiState(
                products: [],
                featuredPlaces: uiState.featuredPlaces,
                searchQuery: uiState.searchQuery,
                selectedCategoryId: uiState.selectedCategoryId,
                isLoading: false,
                errorMessage: e.shouldSuppressUserMessage ? nil : message(for: e)
            )
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
