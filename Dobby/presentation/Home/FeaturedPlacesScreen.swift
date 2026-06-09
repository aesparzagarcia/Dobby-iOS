//
//  FeaturedPlacesScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.FeaturedPlacesScreen`.
//

import SwiftUI
import UIKit

struct FeaturedPlacesScreen: View {
    @State private var viewModel: FeaturedPlacesViewModel

    let onBack: () -> Void
    let onPlaceTap: (FeaturedPlace) -> Void

    init(
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        onBack: @escaping () -> Void = {},
        onPlaceTap: @escaping (FeaturedPlace) -> Void = { _ in }
    ) {
        self.onBack = onBack
        self.onPlaceTap = onPlaceTap
        _viewModel = State(
            initialValue: FeaturedPlacesViewModel(placesRepository: placesRepository, http: httpClient)
        )
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch (viewModel.uiState.isLoading, viewModel.uiState.errorMessage) {
            case (true, _):
                ProgressView()
                    .tint(DobbyBrandColor.primary)
            case (false, let err?) where !err.isEmpty:
                VStack(spacing: 16) {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        viewModel.loadFeaturedPlaces()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DobbyBrandColor.primary)
                }
            default:
                VStack(spacing: 0) {
                    FeaturedPlacesHeader(onBack: onBack)

                    ShopDetailSearchBar(query: Binding(
                        get: { viewModel.uiState.searchQuery },
                        set: { viewModel.onSearchQueryChange($0) }
                    ))
                    .padding(.bottom, 8)

                    HomeCategoryRow(
                        selected: viewModel.uiState.selectedCategory,
                        onCategorySelected: { viewModel.onCategorySelected($0) },
                        includeOffers: false,
                        scale: 0.9,
                        spreadToEdges: true
                    )
                    .padding(.bottom, 4)

                    if viewModel.uiState.filteredPlaces.isEmpty {
                        Spacer()
                        Text(emptyPlacesMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    } else {
                        ScrollView {
                            featuredPlacesGrid(places: viewModel.uiState.filteredPlaces)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyPlacesMessage: String {
        let query = viewModel.uiState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return "Ningún lugar coincide con la búsqueda"
        }
        if viewModel.uiState.selectedCategory != .all {
            return "No hay lugares en esta categoría"
        }
        return "No hay restaurantes ni servicios disponibles"
    }

    private func featuredPlacesGrid(places: [FeaturedPlace]) -> some View {
        let screenW = UIScreen.main.bounds.width
        let inner = screenW - 32
        let spacing: CGFloat = 12
        let cardW = (inner - spacing) / 2

        return LazyVGrid(
            columns: [
                GridItem(.fixed(cardW), spacing: spacing),
                GridItem(.fixed(cardW), spacing: spacing),
            ],
            spacing: 12
        ) {
            ForEach(places) { place in
                HomeFeaturedPlaceCard(
                    place: place,
                    width: cardW,
                    onTap: { onPlaceTap(place) }, cardScale: 1
                )
            }
        }
    }
}
