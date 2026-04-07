//
//  ChosenAddressScreen.swift
//  Dobby
//
//  Parity with Android `MapLocationScreen` when opened from search (chosen address): map under fixed pin, reverse geocode on move end, save via API.
//

import CoreLocation
import MapKit
import SwiftUI

private enum ChosenAddressPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let cardBackground = Color.white
}

/// Same order as Android `MapLocationScreen` / `ADDRESS_LABEL_OPTIONS`.
private let addressLabelOptions = ["Casa", "Apartamento", "Trabajo", "Novia", "Fiesta"]

@MainActor
@Observable
final class ChosenAddressViewModel {
    var editableAddress: String
    var isReverseGeocoding = false
    var isSaving = false
    var errorMessage: String?

    private let places: PlacesAutocompleteRepository
    private let userAddress: UserAddressRepository
    private let http: DobbyHTTPClient

    init(
        initial: NavigateToMapData,
        places: PlacesAutocompleteRepository,
        userAddress: UserAddressRepository,
        http: DobbyHTTPClient
    ) {
        editableAddress = initial.addressLabel
        self.places = places
        self.userAddress = userAddress
        self.http = http
    }

    func onMapCameraEnded(latitude: Double, longitude: Double) {
        Task {
            isReverseGeocoding = true
            errorMessage = nil
            let result = await places.getAddressFromLocation(latitude: latitude, longitude: longitude)
            isReverseGeocoding = false
            switch result {
            case .success(let address):
                editableAddress = address
            case .failure(let e):
                errorMessage = message(for: e)
            }
        }
    }

    /// Parity with Android `MapLocationViewModel.saveAddressWithDescription` (`isDefault: true`).
    func saveAddress(
        label: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        onSuccess: @escaping () -> Void
    ) {
        Task {
            isSaving = true
            errorMessage = nil
            var text = editableAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                switch await places.getAddressFromLocation(latitude: latitude, longitude: longitude) {
                case .success(let a):
                    text = a
                case .failure(let e):
                    isSaving = false
                    errorMessage = message(for: e)
                    return
                }
            }
            let labelStr = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Casa" : label
            let descStr: String? = {
                guard let d = description else { return nil }
                let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }()
            switch await userAddress.createAddress(
                label: labelStr,
                description: descStr,
                address: text,
                lat: latitude,
                lng: longitude,
                isDefault: true
            ) {
            case .success:
                isSaving = false
                onSuccess()
            case .failure(let e):
                isSaving = false
                errorMessage = e.shouldSuppressUserMessage ? nil : message(for: e)
            }
        }
    }

    private func message(for error: PlacesAutocompleteError) -> String {
        switch error {
        case .missingApiKey:
            return "Añade PLACES_API_KEY y activa Geocoding API en Google Cloud."
        case .apiStatus(let s):
            return "Google: \(s)"
        case .noGeometry, .invalidURL:
            return "No se pudo obtener la dirección."
        case .transport(let e):
            return e.localizedDescription
        case .decoding:
            return "Respuesta inválida de Google."
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

struct ChosenAddressScreen: View {
    @State private var viewModel: ChosenAddressViewModel
    @State private var position: MapCameraPosition
    @State private var lastCenter: CLLocationCoordinate2D
    @State private var showSaveSheet = false
    @State private var sheetDescription = ""
    @State private var sheetSelectedLabel = "Casa"

    private let navigateData: NavigateToMapData
    private let onSaveSuccess: () -> Void

    init(
        initial: NavigateToMapData,
        placesAutocompleteRepository: PlacesAutocompleteRepository,
        userAddressRepository: UserAddressRepository,
        httpClient: DobbyHTTPClient,
        onSaveSuccess: @escaping () -> Void
    ) {
        navigateData = initial
        let coord = CLLocationCoordinate2D(latitude: initial.latitude, longitude: initial.longitude)
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
            )
        )
        _lastCenter = State(initialValue: coord)
        _viewModel = State(
            initialValue: ChosenAddressViewModel(
                initial: initial,
                places: placesAutocompleteRepository,
                userAddress: userAddressRepository,
                http: httpClient
            )
        )
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ZStack {
            mapLayer

            VStack {
                addressCard
                Spacer()
                if let err = viewModel.errorMessage, !err.isEmpty, !showSaveSheet {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                saveButton
            }
        }
        .navigationTitle(navigateData.isDeviceLocation ? "Mi ubicación" : "Dirección elegida")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSaveSheet) {
            saveAddressSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.95, green: 0.94, blue: 0.97))
        }
        .onChange(of: showSaveSheet) { _, open in
            if open {
                sheetDescription = ""
                sheetSelectedLabel = "Casa"
                viewModel.errorMessage = nil
            }
        }
    }

    private var saveAddressSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Guardar dirección")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 20)

                Text("Descripción")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                TextField("ej. Casa verde, piso 2", text: $sheetDescription)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .padding(.bottom, 24)

                Text("Etiqueta")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(addressLabelOptions.prefix(3), id: \.self) { option in
                            labelRadioRow(option: option)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(addressLabelOptions.suffix(2), id: \.self) { option in
                            labelRadioRow(option: option)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 24)

                if let err = viewModel.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }

                HStack {
                    Spacer()
                    Button("Cancelar") {
                        showSaveSheet = false
                    }
                    .foregroundStyle(.primary)
                    .disabled(viewModel.isSaving)
                    Button {
                        let desc = sheetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.saveAddress(
                            label: sheetSelectedLabel,
                            description: desc.isEmpty ? nil : desc,
                            latitude: lastCenter.latitude,
                            longitude: lastCenter.longitude
                        ) {
                            showSaveSheet = false
                            onSaveSuccess()
                        }
                    } label: {
                        if viewModel.isSaving {
                            Text("Guardando…")
                        } else {
                            Text("Guardar")
                        }
                    }
                    .foregroundStyle(ChosenAddressPalette.primary)
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.95, green: 0.94, blue: 0.97))
    }

    private func labelRadioRow(option: String) -> some View {
        Button {
            sheetSelectedLabel = option
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: sheetSelectedLabel == option ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(sheetSelectedLabel == option ? ChosenAddressPalette.primary : Color.secondary)
                Text(option)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var mapLayer: some View {
        ZStack {
            Map(position: $position) {}
                .mapStyle(.standard)
                .onMapCameraChange(frequency: .onEnd) { context in
                    let c = context.region.center
                    lastCenter = c
                    viewModel.onMapCameraEnded(latitude: c.latitude, longitude: c.longitude)
                }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ChosenAddressPalette.primary)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .offset(y: -22)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Es esta tu dirección?")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(
                "Dirección",
                text: Binding(
                    get: { viewModel.editableAddress },
                    set: { viewModel.editableAddress = $0 }
                ),
                axis: .vertical
            )
            .lineLimit(1 ... 4)
            .textInputAutocapitalization(.words)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChosenAddressPalette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var saveButton: some View {
        Button {
            showSaveSheet = true
        } label: {
            Text("Guardar dirección")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ChosenAddressPalette.primary)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .disabled(viewModel.isReverseGeocoding)
        .opacity(viewModel.isReverseGeocoding ? 0.65 : 1)
    }
}
