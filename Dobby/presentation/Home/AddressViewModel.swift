//
//  AddressViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.AddressViewModel`.
//

import Foundation

struct AddressUiState: Equatable {
    var searchQuery: String = ""
    var searchResults: [AddressSearchResult] = []
    var myAddresses: [UserAddress] = []
    var showMyAddressesSheet: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var navigateToMapWithLocation: NavigateToMapData?
    var navigateBackToHome: Bool = false
    var isLoadingPlaceDetails: Bool = false
}

private let debounceNs: UInt64 = 350_000_000
private let minQueryLength = 2

@MainActor
@Observable
final class AddressViewModel {
    private let placesAutocomplete: PlacesAutocompleteRepository
    private let userAddressRepository: UserAddressRepository
    private let http: DobbyHTTPClient

    var uiState = AddressUiState()

    private var autocompleteTask: Task<Void, Never>?

    init(
        placesAutocomplete: PlacesAutocompleteRepository,
        userAddressRepository: UserAddressRepository,
        http: DobbyHTTPClient
    ) {
        self.placesAutocomplete = placesAutocomplete
        self.userAddressRepository = userAddressRepository
        self.http = http
    }

    func onSearchQueryChange(_ query: String) {
        updateState {
            $0.searchQuery = query
            $0.errorMessage = nil
            if query.count < minQueryLength {
                $0.searchResults = []
            }
        }
        autocompleteTask?.cancel()
        if query.count < minQueryLength {
            updateState { $0.isLoading = false }
            return
        }
        autocompleteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: debounceNs)
            guard let self, !Task.isCancelled else { return }
            let current = self.uiState.searchQuery
            guard current.count >= minQueryLength else { return }
            self.updateState { $0.isLoading = true; $0.errorMessage = nil }
            let result = await self.placesAutocomplete.getAddressPredictions(input: current)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let predictions):
                let rows = predictions.map { p in
                    AddressSearchResult(id: p.placeId, title: p.mainText, subtitle: p.secondaryText)
                }
                self.updateState {
                    $0.searchResults = rows
                    $0.isLoading = false
                    $0.errorMessage = nil
                }
            case .failure(let e):
                self.updateState {
                    $0.searchResults = []
                    $0.isLoading = false
                    $0.errorMessage = self.message(for: e)
                }
            }
        }
    }

    func clearError() {
        updateState { $0.errorMessage = nil }
    }

    func reportLocationError(_ message: String) {
        updateState { $0.errorMessage = message }
    }

    func onAddressClick(placeId: String, addressLabel: String) {
        Task {
            updateState { $0.isLoadingPlaceDetails = true; $0.errorMessage = nil }
            let result = await placesAutocomplete.getPlaceLocation(placeId: placeId)
            switch result {
            case .success(let pair):
                updateState {
                    $0.isLoadingPlaceDetails = false
                    $0.navigateToMapWithLocation = NavigateToMapData(
                        latitude: pair.0,
                        longitude: pair.1,
                        addressLabel: addressLabel
                    )
                }
            case .failure(let e):
                updateState {
                    $0.isLoadingPlaceDetails = false
                    $0.errorMessage = message(for: e)
                }
            }
        }
    }

    func onNavigatedToMap() {
        updateState { $0.navigateToMapWithLocation = nil }
    }

    func onMyAddressesClick() {
        Task {
            switch await userAddressRepository.getAddresses() {
            case .success(let list):
                updateState {
                    $0.myAddresses = list
                    $0.showMyAddressesSheet = true
                    $0.errorMessage = nil
                }
            case .failure(let e):
                updateState {
                    $0.myAddresses = []
                    $0.showMyAddressesSheet = true
                    $0.errorMessage = e.shouldSuppressUserMessage ? nil : self.message(for: e)
                }
            }
        }
    }

    func onDismissMyAddressesSheet() {
        updateState { $0.showMyAddressesSheet = false }
    }

    func onMyAddressSelected(_ address: UserAddress) {
        Task {
            updateState { $0.showMyAddressesSheet = false }
            switch await userAddressRepository.setDefaultAddress(id: address.id) {
            case .success:
                updateState { $0.navigateBackToHome = true }
            case .failure(let e):
                updateState {
                    $0.showMyAddressesSheet = true
                    $0.errorMessage = e.shouldSuppressUserMessage ? nil : message(for: e)
                }
            }
        }
    }

    func onNavigatedBackToHome() {
        updateState { $0.navigateBackToHome = false }
    }

    /// After saving on the chosen-address map screen, dismiss the whole address flow and refresh home (parity with Android `MapLocationScreen` save).
    func onChosenAddressSaved() {
        updateState { $0.navigateBackToHome = true }
    }

    private func updateState(_ change: (inout AddressUiState) -> Void) {
        var next = uiState
        change(&next)
        uiState = next
    }

    private func message(for error: HomeRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let e):
            return http.userFacingMessage(from: e)
        }
    }

    private func message(for error: PlacesAutocompleteError) -> String {
        switch error {
        case .missingApiKey:
            return "Añade tu clave de Google Places: en Info.plist (PLACES_API_KEY) o en el esquema de Xcode → Environment Variable PLACES_API_KEY. Activa Places API en Google Cloud."
        case .apiStatus(let s):
            return "Google Places: \(s)"
        case .noGeometry:
            return "No se pudo obtener la ubicación."
        case .invalidURL:
            return "Error de configuración de búsqueda."
        case .transport(let e):
            return e.localizedDescription
        case .decoding:
            return "Respuesta inválida de Google Places."
        }
    }
}
