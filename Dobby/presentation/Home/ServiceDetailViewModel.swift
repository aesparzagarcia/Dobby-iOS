//
//  ServiceDetailViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.ServiceDetailViewModel`.
//  Plain class (not @Observable) so form typing never invalidates the screen tree.
//

import Foundation

/// Validated payload ready to add a SERVICE line to the cart.
struct ServicePayPayload: Equatable {
    let service: ServiceDetail
    let serviceNumber: String
    let amount: Double
}

enum ServiceDetailLoadResult: Equatable {
    case success(ServiceDetail)
    case failure(String)
}

@MainActor
final class ServiceDetailViewModel {
    private let serviceId: String
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    private(set) var service: ServiceDetail?
    private(set) var payError: String?

    init(serviceId: String, placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.serviceId = serviceId
        self.placesRepository = placesRepository
        self.http = http
    }

    func load() async -> ServiceDetailLoadResult {
        payError = nil
        switch await placesRepository.getService(id: serviceId) {
        case .success(let service):
            self.service = service
            return .success(service)
        case .failure(let e):
            self.service = nil
            if e.shouldSuppressUserMessage {
                return .failure("No se pudo cargar el servicio.")
            }
            return .failure(message(for: e))
        }
    }

    /// Validates form + service lat/lng before the parent adds to cart.
    func preparePay(serviceNumber: String, amountToPay: String) -> ServicePayPayload? {
        payError = nil
        let number = serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = amountToPay.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0, !number.isEmpty else { return nil }
        guard let service else { return nil }
        guard service.lat != nil, service.lng != nil else {
            payError = "Este servicio no tiene ubicación configurada. Intenta más tarde."
            return nil
        }
        return ServicePayPayload(service: service, serviceNumber: number, amount: amount)
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
