//
//  ShopDetailViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.ShopDetailViewModel`.
//

import Foundation

/// Parity with Android `ShopDetailUiState`.
struct ShopDetailUiState: Equatable {
    var shopName: String = ""
    var shopType: String?
    var products: [ShopProduct] = []
    var searchQuery: String = ""
    var selectedCategoryId: String?
    var shopStatus: String?
    var openingHour: String?
    var closingHour: String?
    var isShopAvailableForOrders: Bool = true
    var isLoading: Bool = false
    var errorMessage: String?

    var showShopClosedBanner: Bool {
        !isShopAvailableForOrders
    }

    var shopReopensLabel: String? {
        HomeShopHours.formatShopReopensLabel(shopStatus: shopStatus, openingHour: openingHour)
    }

    var filteredProducts: [ShopProduct] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCarWash = shopType?.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("CAR_WASH") == .orderedSame
        return products.filter { product in
            (isCarWash || ProductCategory.matchesFilter(productCategory: product.category, filterId: selectedCategoryId))
                && (query.isEmpty || product.name.localizedCaseInsensitiveContains(query))
        }
    }

    var isCarWash: Bool {
        shopType?.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("CAR_WASH") == .orderedSame
    }
}

@MainActor
@Observable
final class ShopDetailViewModel {
    private let shopId: String
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState: ShopDetailUiState

    init(
        shopId: String,
        shopName: String,
        placesRepository: PlacesRepository,
        http: DobbyHTTPClient,
        shopType: String? = nil,
        openingHour: String? = nil,
        closingHour: String? = nil
    ) {
        self.shopId = shopId
        self.placesRepository = placesRepository
        self.http = http
        uiState = ShopDetailUiState(
            shopName: shopName,
            shopType: shopType,
            openingHour: openingHour,
            closingHour: closingHour,
            isShopAvailableForOrders: HomeShopHours.isShopAvailableForOrders(
                shopStatus: "ACTIVE",
                openingHour: openingHour,
                closingHour: closingHour
            ),
            isLoading: true
        )
        Task { await loadProductsAsync() }
    }

    func loadProducts() {
        Task { await loadProductsAsync() }
    }

    func onSearchQueryChange(_ query: String) {
        uiState.searchQuery = query
    }

    func onCategorySelected(_ categoryId: String?) {
        uiState.selectedCategoryId = categoryId
    }

    private func loadProductsAsync() async {
        uiState.errorMessage = nil
        uiState.isLoading = true

        switch await placesRepository.getShopProducts(shopId: shopId) {
        case .success(let page):
            let isCarWash = page.shopType?.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("CAR_WASH") == .orderedSame
            uiState = ShopDetailUiState(
                shopName: uiState.shopName,
                shopType: page.shopType,
                products: page.products,
                searchQuery: uiState.searchQuery,
                selectedCategoryId: isCarWash ? nil : uiState.selectedCategoryId,
                shopStatus: page.shopStatus,
                openingHour: page.openingHour,
                closingHour: page.closingHour,
                isShopAvailableForOrders: page.isShopAvailableForOrders,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = ShopDetailUiState(
                shopName: uiState.shopName,
                shopType: uiState.shopType,
                products: [],
                searchQuery: uiState.searchQuery,
                selectedCategoryId: uiState.selectedCategoryId,
                isShopAvailableForOrders: true,
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
