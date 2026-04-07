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
    var products: [ShopProduct] = []
    var isLoading: Bool = false
    var errorMessage: String?
}

@MainActor
@Observable
final class ShopDetailViewModel {
    private let shopId: String
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState: ShopDetailUiState

    init(shopId: String, shopName: String, placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.shopId = shopId
        self.placesRepository = placesRepository
        self.http = http
        uiState = ShopDetailUiState(shopName: shopName, isLoading: true)
        Task { await loadProductsAsync() }
    }

    /// Parity with Android `loadProducts()`.
    func loadProducts() {
        Task { await loadProductsAsync() }
    }

    private func loadProductsAsync() async {
        uiState.errorMessage = nil
        uiState.isLoading = true

        switch await placesRepository.getShopProducts(shopId: shopId) {
        case .success(let products):
            uiState = ShopDetailUiState(
                shopName: uiState.shopName,
                products: products,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = ShopDetailUiState(
                shopName: uiState.shopName,
                products: [],
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
