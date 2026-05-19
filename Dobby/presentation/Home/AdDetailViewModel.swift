//
//  AdDetailViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.AdDetailViewModel`.
//

import Foundation

/// Parity with Android `AdDetailUiState`.
struct AdDetailUiState: Equatable {
    var ad: Ad?
    var isLoading: Bool = true
    var errorMessage: String?
}

@MainActor
@Observable
final class AdDetailViewModel {
    private let adId: String
    private let adsRepository: AdsRepository
    private let http: DobbyHTTPClient

    var uiState: AdDetailUiState

    init(adId: String, adsRepository: AdsRepository, http: DobbyHTTPClient) {
        self.adId = adId
        self.adsRepository = adsRepository
        self.http = http
        uiState = AdDetailUiState()
        Task { await loadAdAsync() }
    }

    func loadAd() {
        Task { await loadAdAsync() }
    }

    private func loadAdAsync() async {
        uiState = AdDetailUiState(ad: uiState.ad, isLoading: true, errorMessage: nil)

        switch await adsRepository.getAd(id: adId) {
        case .success(let ad):
            uiState = AdDetailUiState(
                ad: ad,
                isLoading: false,
                errorMessage: ad == nil ? "No encontrado: anuncio no disponible" : nil
            )
        case .failure(let e):
            uiState = AdDetailUiState(
                ad: nil,
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
