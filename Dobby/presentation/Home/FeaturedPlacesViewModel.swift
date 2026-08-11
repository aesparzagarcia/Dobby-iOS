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
    var isRefreshing: Bool = false
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

    var uiState = FeaturedPlacesUiState()

    init(placesRepository: PlacesRepository, http: DobbyHTTPClient) {
        self.placesRepository = placesRepository
        self.http = http
        uiState.isLoading = true
        Task { await loadFeaturedPlacesAsync(isRefresh: false) }
    }

    func loadFeaturedPlaces() {
        Task { await loadFeaturedPlacesAsync(isRefresh: false) }
    }

    func refresh() async {
        await loadFeaturedPlacesAsync(isRefresh: true)
    }

    func onSearchQueryChange(_ query: String) {
        uiState.searchQuery = query
    }

    func onCategorySelected(_ category: HomeQuickCategory) {
        uiState.selectedCategory = category
    }

    private func loadFeaturedPlacesAsync(isRefresh: Bool) async {
        if isRefresh {
            guard !uiState.isRefreshing, !uiState.isLoading else { return }
            uiState.isRefreshing = true
            uiState.errorMessage = nil
        } else {
            uiState.errorMessage = nil
            uiState.isLoading = true
        }

        switch await placesRepository.getFeaturedPlaces() {
        case .success(let places):
            uiState = FeaturedPlacesUiState(
                places: HomeShopHours.sortFeaturedPlacesByAvailability(places: places),
                searchQuery: uiState.searchQuery,
                selectedCategory: uiState.selectedCategory,
                isLoading: false,
                isRefreshing: false,
                errorMessage: nil
            )
        case .failure(let e):
            uiState = FeaturedPlacesUiState(
                places: isRefresh ? uiState.places : [],
                searchQuery: uiState.searchQuery,
                selectedCategory: uiState.selectedCategory,
                isLoading: false,
                isRefreshing: false,
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
