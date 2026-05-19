//
//  ServiceDetailViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.ServiceDetailViewModel`.
//

import Foundation

/// Parity with Android `ServiceDetailUiState`.
struct ServiceDetailUiState: Equatable {
    var service: ServiceDetail?
    var amountToPay: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
}

@MainActor
@Observable
final class ServiceDetailViewModel {
    private let serviceId: String
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState: ServiceDetailUiState

    init(serviceId: String, placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.serviceId = serviceId
        self.placesRepository = placesRepository
        self.http = http
        uiState = ServiceDetailUiState(isLoading: true)
        Task { await loadServiceAsync() }
    }

    func loadService() {
        Task { await loadServiceAsync() }
    }

    func onAmountChange(_ value: String) {
        uiState = ServiceDetailUiState(
            service: uiState.service,
            amountToPay: value,
            isLoading: uiState.isLoading,
            errorMessage: uiState.errorMessage
        )
    }

    private func loadServiceAsync() async {
        uiState.errorMessage = nil
        uiState.isLoading = true

        switch await placesRepository.getService(id: serviceId) {
        case .success(let service):
            uiState = ServiceDetailUiState(
                service: service,
                amountToPay: uiState.amountToPay,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = ServiceDetailUiState(
                service: nil,
                amountToPay: uiState.amountToPay,
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
