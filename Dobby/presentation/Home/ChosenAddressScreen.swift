//
//  ChosenAddressScreen.swift
//  Dobby
//
//  Parity with Android `MapLocationScreen`: full-screen map, center pin, blue floating address card,
//  green confirm button, “Dirección lejana” alert when pin >200m from start, save sheet.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

// MARK: - Palette (Android `FloatingAddressCardColor` / `ConfirmButtonColor`)

private enum MapLocationLikePalette {
    static let cardBlue = Color(red: 0x39 / 255, green: 0x67 / 255, blue: 0xFF / 255)
    static let confirmGreen = Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255)
}

/// Same order as Android `MapLocationScreen` / `ADDRESS_LABEL_OPTIONS`.
private let addressLabelOptions = ["Casa", "Apartamento", "Trabajo", "Novia", "Fiesta"]

private func addressCardPreview(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "Dirección no disponible" }
    let segments = trimmed.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    if segments.isEmpty { return "Dirección no disponible" }
    let street = segments[0]
    let neighborhood = segments.count > 1 ? segments[1] : ""
    if neighborhood.isEmpty { return street }
    return "\(street), \(neighborhood)"
}

private func distanceMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

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
        Task { @MainActor in
            isReverseGeocoding = true
            errorMessage = nil
            let result = await places.getAddressFromLocation(latitude: latitude, longitude: longitude)
            isReverseGeocoding = false
            switch result {
            case .success(let address):
                editableAddress = address
            case .failure(let e):
                errorMessage = message(for: e)
                let coordFallback = String(format: "%.5f, %.5f", latitude, longitude)
                if editableAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    editableAddress = coordFallback
                }
            }
        }
    }

    func saveAddress(
        label: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        onSuccess: @escaping () -> Void
    ) {
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            guard DeliveryServiceArea.contains(latitude: latitude, longitude: longitude) else {
                isSaving = false
                if DeliveryServiceArea.isConfigBlockingSaves {
                    errorMessage = DeliveryServiceArea.denialMessage()
                } else {
                    errorMessage = DeliveryServiceArea.outsideLimitsLabel
                }
                return
            }
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
    /// Fixed start position for Android-parity “>200m” warning (`MapLocationScreen` / `userStartLocation`).
    private let userStartCoordinate: CLLocationCoordinate2D

    @State private var showSaveSheet = false
    @State private var showFarLocationAlert = false
    @State private var sheetDescription = ""
    @State private var sheetSelectedLabel = "Casa"
    @State private var isRecentering = false

    private let navigateData: NavigateToMapData
    private let onSaveSuccess: () -> Void

    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)

    init(
        initial: NavigateToMapData,
        placesAutocompleteRepository: PlacesAutocompleteRepository,
        userAddressRepository: UserAddressRepository,
        httpClient: DobbyHTTPClient,
        onSaveSuccess: @escaping () -> Void
    ) {
        navigateData = initial
        let coord = CLLocationCoordinate2D(latitude: initial.latitude, longitude: initial.longitude)
        userStartCoordinate = coord
        _position = State(
            initialValue: .region(MKCoordinateRegion(center: coord, span: Self.defaultSpan))
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

    private func shouldOpenSaveSheetAfterAreaCheck() -> Bool {
        if DeliveryServiceArea.isConfigBlockingSaves {
            viewModel.errorMessage = nil
            return false
        }
        if DeliveryServiceArea.hasValidEnforcedPolygon {
            guard DeliveryServiceArea.contains(latitude: lastCenter.latitude, longitude: lastCenter.longitude) else {
                viewModel.errorMessage = nil
                return false
            }
        }
        viewModel.errorMessage = nil
        return true
    }

    var body: some View {
        ZStack {
            mapAndPinLayer

            addressFloatingCard

            VStack {
                HStack {
                    Spacer()
                    recenterButton
                }
                .padding(.top, 8)
                .padding(.trailing, 12)
                Spacer()
            }

            VStack {
                Spacer()
                if let err = viewModel.errorMessage, !err.isEmpty, !showSaveSheet {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
                confirmLocationButton
            }
        }
        .background(Color.white)
        .navigationTitle(navigateData.isDeviceLocation ? "Mi ubicación" : "Dirección elegida")
        .navigationBarTitleDisplayMode(.inline)
        .background(MinimalBackButtonDisplayModeBridge())
        .toolbarBackground(Color.white, for: ToolbarPlacement.navigationBar)
        .toolbarBackground(Visibility.visible, for: ToolbarPlacement.navigationBar)
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
        .alert("Dirección lejana", isPresented: $showFarLocationAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, continuar") {
                showFarLocationAlert = false
                if shouldOpenSaveSheetAfterAreaCheck() {
                    showSaveSheet = true
                }
            }
        } message: {
            Text("El pin está a más de 200 metros de tu ubicación actual. ¿Deseas continuar?")
        }
    }

    // MARK: - Map + pin (Android: GoogleMap + center LocationOn; iOS: SF pin over map center)

    private var mapAndPinLayer: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapStyle(.standard)
            // `region.center` puede no coincidir con el centro real de la cámara; `camera.centerCoordinate` sí.
            // Actualizar en continuo para que el botón "dentro/fuera" siga el pin mientras mueves el mapa.
            .onMapCameraChange(frequency: .continuous) { context in
                let c = context.camera.centerCoordinate
                if c.latitude.isFinite && c.longitude.isFinite {
                    lastCenter = c
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let c = context.camera.centerCoordinate
                if c.latitude.isFinite && c.longitude.isFinite {
                    lastCenter = c
                }
                viewModel.onMapCameraEnded(latitude: c.latitude, longitude: c.longitude)
            }

            Image(systemName: "pin.fill")
                .font(.system(size: 48))
                .foregroundStyle(MapLocationLikePalette.cardBlue)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Android: Card centered, `AddressCardOffsetFromPin` = −67dp
    private var addressFloatingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ajusta la ubicación de entrega")
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
            Text(addressCardPreview(viewModel.editableAddress))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MapLocationLikePalette.cardBlue)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -67)
        .allowsHitTesting(false)
    }

    private var recenterButton: some View {
        Button {
            Task { await recenterOnDeviceLocation() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                if isRecentering {
                    ProgressView()
                        .tint(MapLocationLikePalette.cardBlue)
                } else {
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MapLocationLikePalette.cardBlue)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isRecentering)
        .accessibilityLabel("Centrar en mi ubicación")
    }

    private func recenterOnDeviceLocation() async {
        isRecentering = true
        defer { isRecentering = false }
        viewModel.errorMessage = nil
        do {
            let loc = try await OneShotLocationRequest().getLocation()
            let c = loc.coordinate
            position = .region(MKCoordinateRegion(center: c, span: Self.defaultSpan))
            lastCenter = c
            viewModel.onMapCameraEnded(latitude: c.latitude, longitude: c.longitude)
        } catch {
            let msg: String
            if let le = error as? LocalizedError, let d = le.errorDescription, !d.isEmpty {
                msg = d
            } else {
                msg = error.localizedDescription
            }
            viewModel.errorMessage = msg
        }
    }

    private var confirmLocationButton: some View {
        let canConfirmByArea: Bool = {
            if DeliveryServiceArea.isConfigBlockingSaves { return false }
            if DeliveryServiceArea.hasValidEnforcedPolygon {
                return DeliveryServiceArea.contains(latitude: lastCenter.latitude, longitude: lastCenter.longitude)
            }
            return true
        }()
        let title: String = {
            if viewModel.isReverseGeocoding { return "Guardando…" }
            if DeliveryServiceArea.isConfigBlockingSaves { return DeliveryServiceArea.configFixLabel }
            if DeliveryServiceArea.hasValidEnforcedPolygon,
               !DeliveryServiceArea.contains(latitude: lastCenter.latitude, longitude: lastCenter.longitude) {
                return DeliveryServiceArea.outsideLimitsLabel
            }
            return "Confirmar ubicación"
        }()
        let useGreen = canConfirmByArea && !viewModel.isReverseGeocoding
        return Button {
            let meters = distanceMeters(from: userStartCoordinate, to: lastCenter)
            if meters > 200 {
                showFarLocationAlert = true
            } else if shouldOpenSaveSheetAfterAreaCheck() {
                showSaveSheet = true
            }
        } label: {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(useGreen ? MapLocationLikePalette.confirmGreen : Color(.systemGray3))
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .disabled(!canConfirmByArea || viewModel.isReverseGeocoding)
        .opacity(viewModel.isReverseGeocoding ? 0.65 : 1)
    }

    // MARK: - Save sheet (Android `ModalBottomSheet`)

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
                    .foregroundStyle(MapLocationLikePalette.cardBlue)
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
                    .foregroundStyle(sheetSelectedLabel == option ? MapLocationLikePalette.cardBlue : Color.secondary)
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
}

// MARK: - Back chevron only (SwiftUI may omit `navigationBarBackButtonDisplayMode` on newer SDKs)

/// Sets `UINavigationItem.backButtonDisplayMode` on the hosting controller so only the chevron shows.
private struct MinimalBackButtonDisplayModeBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.isUserInteractionEnabled = false
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            var walker: UIViewController? = uiViewController
            while let c = walker {
                if let nav = c.navigationController {
                    nav.topViewController?.navigationItem.backButtonDisplayMode = .minimal
                    return
                }
                walker = c.parent
            }
        }
    }
}
