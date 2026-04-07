//
//  CurrentAddressScreen.swift
//  Dobby
//
//  Parity with Android `AddressScreen.kt` (search + Places autocomplete + actions + sheet).
//

import SwiftUI

private enum AddressScreenPalette {
    static let background = Color(red: 248 / 255, green: 244 / 255, blue: 255 / 255)
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let actionFill = Color(red: 0.93, green: 0.90, blue: 0.98)
    static let border = Color(.systemGray4)
}

/// Shown when the user taps the delivery address on the home header (Android: “My current address”).
struct CurrentAddressScreen: View {
    @Environment(\.dismiss) private var dismiss

    var onDefaultAddressUpdated: () -> Void

    private let placesAutocompleteRepository: PlacesAutocompleteRepository
    private let userAddressRepository: UserAddressRepository
    private let httpClient: DobbyHTTPClient

    @State private var addressViewModel: AddressViewModel
    @State private var chosenAddressRoute: NavigateToMapData?
    @State private var isFetchingDeviceLocation = false

    init(
        placesAutocompleteRepository: PlacesAutocompleteRepository,
        userAddressRepository: UserAddressRepository,
        httpClient: DobbyHTTPClient,
        onDefaultAddressUpdated: @escaping () -> Void
    ) {
        self.onDefaultAddressUpdated = onDefaultAddressUpdated
        self.placesAutocompleteRepository = placesAutocompleteRepository
        self.userAddressRepository = userAddressRepository
        self.httpClient = httpClient
        _addressViewModel = State(
            initialValue: AddressViewModel(
                placesAutocomplete: placesAutocompleteRepository,
                userAddressRepository: userAddressRepository,
                http: httpClient
            )
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if let err = addressViewModel.uiState.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                VStack(spacing: 12) {
                    actionRow(
                        title: "Mis direcciones",
                        systemImage: "house.fill",
                        action: { addressViewModel.onMyAddressesClick() }
                    )
                    actionRow(
                        title: "Mi ubicación actual",
                        systemImage: "location.circle.fill",
                        action: { openMyCurrentLocation() }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(addressViewModel.uiState.searchResults) { result in
                            AddressResultItem(
                                title: result.title,
                                subtitle: result.subtitle,
                                onClick: {
                                    let label: String
                                    if let sub = result.subtitle, !sub.isEmpty {
                                        label = "\(result.title), \(sub)"
                                    } else {
                                        label = result.title
                                    }
                                    addressViewModel.onAddressClick(placeId: result.id, addressLabel: label)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }

            if addressViewModel.uiState.isLoadingPlaceDetails || isFetchingDeviceLocation {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Cargando ubicación…")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AddressScreenPalette.background)
        .navigationTitle("Mi dirección actual")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Atrás")
            }
        }
        .sheet(
            isPresented: Binding(
                get: { addressViewModel.uiState.showMyAddressesSheet },
                set: { new in
                    if !new {
                        addressViewModel.onDismissMyAddressesSheet()
                    }
                }
            )
        ) {
            MyAddressesBottomSheet(
                uiState: addressViewModel.uiState,
                onSelect: { addressViewModel.onMyAddressSelected($0) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(red: 243 / 255, green: 240 / 255, blue: 247 / 255))
        }
        .navigationDestination(item: $chosenAddressRoute) { nav in
            ChosenAddressScreen(
                initial: nav,
                placesAutocompleteRepository: placesAutocompleteRepository,
                userAddressRepository: userAddressRepository,
                httpClient: httpClient,
                onSaveSuccess: {
                    chosenAddressRoute = nil
                    addressViewModel.onChosenAddressSaved()
                }
            )
        }
        .onChange(of: addressViewModel.uiState.navigateBackToHome) { _, go in
            if go {
                addressViewModel.onNavigatedBackToHome()
                onDefaultAddressUpdated()
                dismiss()
            }
        }
        .onChange(of: addressViewModel.uiState.navigateToMapWithLocation) { _, nav in
            guard let nav else { return }
            chosenAddressRoute = nav
            addressViewModel.onNavigatedToMap()
        }
    }

    private func openMyCurrentLocation() {
        Task { @MainActor in
            addressViewModel.clearError()
            isFetchingDeviceLocation = true
            defer { isFetchingDeviceLocation = false }
            let request = OneShotLocationRequest()
            do {
                let loc = try await request.getLocation()
                let c = loc.coordinate
                let label: String
                switch await placesAutocompleteRepository.getAddressFromLocation(
                    latitude: c.latitude,
                    longitude: c.longitude
                ) {
                case .success(let a):
                    label = a
                case .failure:
                    label = "Ubicación actual"
                }
                chosenAddressRoute = NavigateToMapData(
                    latitude: c.latitude,
                    longitude: c.longitude,
                    addressLabel: label,
                    isDeviceLocation: true
                )
            } catch {
                let msg: String
                if let le = error as? LocalizedError, let d = le.errorDescription, !d.isEmpty {
                    msg = d
                } else {
                    msg = error.localizedDescription
                }
                addressViewModel.reportLocationError(msg)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "Buscar dirección",
                text: Binding(
                    get: { addressViewModel.uiState.searchQuery },
                    set: { addressViewModel.onSearchQueryChange($0) }
                )
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(false)
            if addressViewModel.uiState.isLoading {
                ProgressView()
                    .scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AddressScreenPalette.primary.opacity(0.45), lineWidth: 1)
        )
    }

    private func actionRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(AddressScreenPalette.primary)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AddressScreenPalette.actionFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddressResultItem (Android `AddressResultItem`)

private struct AddressResultItem: View {
    let title: String
    let subtitle: String?
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}
