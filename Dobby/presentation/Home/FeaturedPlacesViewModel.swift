//
//  FeaturedPlacesViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.home.FeaturedPlacesViewModel`.
//

import Foundation

struct FeaturedPlacesUiState: Equatable {
    var places: [FeaturedPlace] = []
    var searchQuery: String = ""
    var selectedCategory: HomeQuickCategory = .all
    var isLoading: Bool = false
    var errorMessage: String?

    var filteredPlaces: [FeaturedPlace] {
        let byCategory = filterPlacesByCategory(places, category: selectedCategory)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return byCategory }
        return byCategory.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

@MainActor
@Observable
final class FeaturedPlacesViewModel {
    private let placesRepository: PlacesRepository
    private let http: DobbyHTTPClient

    var uiState: FeaturedPlacesUiState

    init(placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.placesRepository = placesRepository
        self.http = http
        uiState = FeaturedPlacesUiState(isLoading: true)
        Task { await loadFeaturedPlacesAsync() }
    }

    func loadFeaturedPlaces() {
        Task { await loadFeaturedPlacesAsync() }
    }

    func onSearchQueryChange(_ query: String) {
        uiState.searchQuery = query
    }

    func onCategorySelected(_ category: HomeQuickCategory) {
        uiState.selectedCategory = category
    }

    private func loadFeaturedPlacesAsync() async {
        uiState.errorMessage = nil
        uiState.isLoading = true

        switch await placesRepository.getFeaturedPlaces() {
        case .success(let places):
            uiState = FeaturedPlacesUiState(
                places: places,
                searchQuery: uiState.searchQuery,
                selectedCategory: uiState.selectedCategory,
                isLoading: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = FeaturedPlacesUiState(
                places: [],
                searchQuery: uiState.searchQuery,
                selectedCategory: uiState.selectedCategory,
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
