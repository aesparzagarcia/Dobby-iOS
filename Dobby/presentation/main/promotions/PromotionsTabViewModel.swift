//
//  PromotionsTabViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.promotions.PromotionsTabViewModel`.
//

import Foundation

/// Parity with Android `PromotionsUiState`.
struct PromotionsUiState: Sendable {
    var products: [BestSellerProduct] = []
    var isLoading: Bool = false
    var errorMessage: String?
}

@MainActor
@Observable
final class PromotionsTabViewModel {
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState = PromotionsUiState(isLoading: true)

    init(placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.placesRepository = placesRepository
        self.http = http
        Task { await fetchPromotions() }
    }

    /// Parity with Android `loadPromotions()` — filters `hasPromotion && discount > 0`.
    func loadPromotions() {
        Task { await fetchPromotions() }
    }

    func refresh() async {
        await fetchPromotions()
    }

    private func fetchPromotions() async {
        uiState.isLoading = true
        uiState.errorMessage = nil
        switch await placesRepository.getPromotions() {
        case .success(let list):
            let promotions = list.filter { $0.hasPromotion && $0.discount > 0 }
            uiState = PromotionsUiState(
                products: promotions,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = PromotionsUiState(
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
