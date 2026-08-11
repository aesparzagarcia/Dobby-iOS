//
//  CurrentAddressScreen.swift
//  Dobby
//
//  Parity with Android `AddressScreen.kt` — redesigned “Mis direcciones”.
//

import MapKit
import SwiftUI

private enum AddressScreenPalette {
    static let background = Color(red: 247 / 255, green: 248 / 255, blue: 250 / 255)
    static let cardBorder = Color(red: 232 / 255, green: 234 / 255, blue: 239 / 255)
    static let muted = Color(red: 138 / 255, green: 143 / 255, blue: 152 / 255)
    static let locationBlue = Color(red: 47 / 255, green: 107 / 255, blue: 1)
    static let principalBg = Color(red: 232 / 255, green: 240 / 255, blue: 1)
    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 20.6507582, longitude: -103.7029606)
}

/// Shown when the user taps the delivery address on the home header.
struct CurrentAddressScreen: View {
    @Environment(\.dismiss) private var dismiss

    var onDefaultAddressUpdated: () -> Void
    var isLoggedIn: Bool = true
    var onRequireLogin: () -> Void = {}

    private let placesAutocompleteRepository: PlacesAutocompleteRepository
    private let userAddressRepository: UserAddressRepository
    private let httpClient: DobbyHTTPClient

    @State private var addressViewModel: AddressViewModel
    @State private var chosenAddressRoute: NavigateToMapData?
    @State private var isFetchingDeviceLocation = false
    @FocusState private var searchFieldFocused: Bool

    init(
        placesAutocompleteRepository: PlacesAutocompleteRepository,
        userAddressRepository: UserAddressRepository,
        httpClient: DobbyHTTPClient,
        onDefaultAddressUpdated: @escaping () -> Void,
        isLoggedIn: Bool = true,
        onRequireLogin: @escaping () -> Void = {}
    ) {
        self.onDefaultAddressUpdated = onDefaultAddressUpdated
        self.isLoggedIn = isLoggedIn
        self.onRequireLogin = onRequireLogin
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
            AddressScreenPalette.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                if isLoggedIn {
                    loggedInContent
                } else {
                    guestLoginContent
                }
            }

            if addressViewModel.uiState.isLoadingPlaceDetails || isFetchingDeviceLocation {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AddressScreenPalette.locationBlue)
                    Text("Cargando ubicación…")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
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
            .toolbar(.visible, for: .navigationBar)
        }
        .onAppear {
            guard isLoggedIn else { return }
            addressViewModel.onAppear()
            loadDeviceLocationPreview()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DobbyBrandColor.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Text("Mis direcciones")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DobbyBrandColor.textPrimary)

            Text("Selecciona o agrega la dirección donde quieres que te lleguen tus pedidos.")
                .font(.subheadline)
                .foregroundStyle(AddressScreenPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var loggedInContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                searchField

                if let err = addressViewModel.uiState.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !addressViewModel.uiState.searchResults.isEmpty {
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
                } else {
                    CurrentLocationCard(
                        latitude: addressViewModel.uiState.deviceLatitude,
                        longitude: addressViewModel.uiState.deviceLongitude,
                        addressText: addressViewModel.uiState.deviceLocationAddress,
                        isLoading: addressViewModel.uiState.isLoadingDeviceLocation,
                        onClick: { openMyCurrentLocation() }
                    )

                    HStack {
                        Text("Mis direcciones guardadas")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DobbyBrandColor.textPrimary)
                        Spacer(minLength: 8)
                        Button {
                            addressViewModel.onSearchQueryChange("")
                            searchFieldFocused = true
                        } label: {
                            Text("+ Agregar nueva")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AddressScreenPalette.locationBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    if addressViewModel.uiState.isLoadingAddresses && addressViewModel.uiState.myAddresses.isEmpty {
                        ProgressView()
                            .tint(AddressScreenPalette.locationBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if addressViewModel.uiState.myAddresses.isEmpty {
                        Text("No hay direcciones guardadas")
                            .font(.body)
                            .foregroundStyle(AddressScreenPalette.muted)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(addressViewModel.uiState.myAddresses) { address in
                            SavedAddressCard(
                                address: address,
                                onSelect: { addressViewModel.onMyAddressSelected(address) },
                                onSetDefault: { addressViewModel.onSetAsDefault(address) },
                                onDelete: { addressViewModel.onDeleteAddress(address) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var guestLoginContent: some View {
        VStack(spacing: 16) {
            Text("Inicia sesión para guardar y administrar tu dirección de entrega.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Button {
                dismiss()
                onRequireLogin()
            } label: {
                Text("Inicia sesión para continuar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(DobbyBrandColor.primary)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadDeviceLocationPreview() {
        Task { @MainActor in
            addressViewModel.setLoadingDeviceLocation(true)
            let request = OneShotLocationRequest()
            do {
                let loc = try await request.getLocation()
                let c = loc.coordinate
                var label: String?
                switch await placesAutocompleteRepository.getAddressFromLocation(
                    latitude: c.latitude,
                    longitude: c.longitude
                ) {
                case .success(let a):
                    label = a
                case .failure:
                    label = nil
                }
                addressViewModel.refreshDeviceLocation(coordinate: c, addressLabel: label)
            } catch {
                addressViewModel.setLoadingDeviceLocation(false)
            }
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
                addressViewModel.refreshDeviceLocation(coordinate: c, addressLabel: label)
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
                .foregroundStyle(AddressScreenPalette.muted)
            TextField(
                "Buscar dirección, colonia o ciudad",
                text: Binding(
                    get: { addressViewModel.uiState.searchQuery },
                    set: { addressViewModel.onSearchQueryChange($0) }
                )
            )
            .focused($searchFieldFocused)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(false)
            if addressViewModel.uiState.isLoading {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(AddressScreenPalette.locationBlue)
            } else {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(DobbyBrandColor.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AddressScreenPalette.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Current location card

private struct CurrentLocationCard: View {
    let latitude: Double?
    let longitude: Double?
    let addressText: String?
    let isLoading: Bool
    let onClick: () -> Void

    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: AddressScreenPalette.fallbackCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    )

    private var coordinate: CLLocationCoordinate2D {
        if let latitude, let longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return AddressScreenPalette.fallbackCoordinate
    }

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Map(position: $mapPosition) {
                        if latitude != nil, longitude != nil {
                            Annotation("", coordinate: coordinate) {
                                Circle()
                                    .fill(AddressScreenPalette.locationBlue)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: AddressScreenPalette.locationBlue.opacity(0.35), radius: 6)
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .disabled(true)
                    .frame(height: 148)
                    .allowsHitTesting(false)

                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Ubicación actual")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(DobbyBrandColor.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white, in: Capsule())
                    .padding(12)

                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DobbyBrandColor.primary, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(12)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 18))

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usar mi ubicación actual")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DobbyBrandColor.textPrimary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AddressScreenPalette.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AddressScreenPalette.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AddressScreenPalette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onChange(of: latitude) { _, _ in syncMapPosition() }
        .onChange(of: longitude) { _, _ in syncMapPosition() }
        .onAppear { syncMapPosition() }
    }

    private func syncMapPosition() {
        mapPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        )
    }

    private var subtitle: String {
        if isLoading { return "Obteniendo ubicación…" }
        if let addressText, !addressText.isEmpty { return addressText }
        return "Toca para confirmar en el mapa"
    }
}

// MARK: - Saved address card

private struct SavedAddressCard: View {
    let address: UserAddress
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let style = AddressLabelVisual.style(for: address.label)
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: style.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(style.background, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(address.label.isEmpty ? "Dirección" : address.label)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(DobbyBrandColor.textPrimary)
                            if address.isDefault {
                                Text("Principal")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AddressScreenPalette.locationBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AddressScreenPalette.principalBg, in: Capsule())
                            }
                        }
                        Text(address.address.addressWithColonyOnly())
                            .font(.caption)
                            .foregroundStyle(AddressScreenPalette.muted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                if !address.isDefault {
                    Button("Establecer como principal", action: onSetDefault)
                }
                Button("Eliminar", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(AddressScreenPalette.muted)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AddressScreenPalette.cardBorder, lineWidth: 1)
        )
    }
}

private enum AddressLabelVisual {
    struct Style {
        let systemImage: String
        let background: Color
    }

    static func style(for label: String) -> Style {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "casa", "home":
            return Style(systemImage: "house.fill", background: AddressScreenPalette.locationBlue)
        case "trabajo", "work":
            return Style(systemImage: "briefcase.fill", background: Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255))
        case "gimnasio", "gym":
            return Style(systemImage: "dumbbell.fill", background: Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255))
        case "novia":
            return Style(systemImage: "heart.fill", background: Color(red: 1, green: 45 / 255, blue: 85 / 255))
        case "apartamento":
            return Style(systemImage: "building.2.fill", background: Color(red: 88 / 255, green: 86 / 255, blue: 214 / 255))
        case "fiesta":
            return Style(systemImage: "party.popper.fill", background: Color(red: 1, green: 149 / 255, blue: 0))
        default:
            return Style(systemImage: "mappin.and.ellipse", background: DobbyPureScale.graphite)
        }
    }
}

// MARK: - AddressResultItem

private struct AddressResultItem: View {
    let title: String
    let subtitle: String?
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DobbyBrandColor.textPrimary)
                    .multilineTextAlignment(.leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AddressScreenPalette.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AddressScreenPalette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
