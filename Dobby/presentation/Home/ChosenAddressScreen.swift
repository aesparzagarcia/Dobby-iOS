//
//  ChosenAddressScreen.swift
//  Dobby
//
//  Parity with Android `MapLocationScreen`: full-screen map, center pin, floating address card,
//  confirm button (PhoneScreen style), “Dirección lejana” alert when pin >200m from start, save sheet.
//

import CoreLocation
import MapKit
import SwiftUI

// MARK: - Palette (Android `FloatingAddressCardColor`)

private enum MapLocationLikePalette {
    static let cardBlue = DobbyBrandColor.primary
}

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
        addressText: String? = nil,
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
            var text = if let edited = addressText?.trimmingCharacters(in: .whitespacesAndNewlines), !edited.isEmpty {
                editableAddress.withEditedStreetAndColony(edited)
            } else {
                editableAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            }
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
            switch await userAddress.getAddresses() {
            case .success(let existing):
                if AddressDuplicate.isDuplicate(
                    existing: existing,
                    address: text,
                    lat: latitude,
                    lng: longitude
                ) {
                    isSaving = false
                    errorMessage = AddressDuplicate.message
                    return
                }
            case .failure:
                break
            }
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
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChosenAddressViewModel
    @State private var position: MapCameraPosition
    @State private var lastCenter: CLLocationCoordinate2D
    /// Fixed start position for Android-parity “>200m” warning (`MapLocationScreen` / `userStartLocation`).
    private let userStartCoordinate: CLLocationCoordinate2D

    @State private var showSaveSheet = false
    @State private var showFarLocationAlert = false
    @State private var sheetAddress = ""
    @State private var sheetDescription = ""
    @State private var sheetSelectedLabel = "Casa"
    @State private var isRecentering = false
    @State private var saveSheetContentHeight: CGFloat = 620

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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationBackButton(action: { dismiss() })
            }
        }
        .toolbarBackground(Color.white, for: ToolbarPlacement.navigationBar)
        .toolbarBackground(Visibility.visible, for: ToolbarPlacement.navigationBar)
        .sheet(isPresented: $showSaveSheet) {
            saveAddressSheet
                .presentationDetents([.height(saveSheetContentHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(saveSheetCornerRadius)
                .presentationBackground {
                    RoundedRectangle(cornerRadius: saveSheetCornerRadius, style: .continuous)
                        .fill(Color.white)
                }
                .presentationContentInteraction(.scrolls)
        }
        .onChange(of: showSaveSheet) { _, open in
            if open {
                sheetAddress = viewModel.editableAddress.addressWithColonyOnly()
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
        let usePrimary = canConfirmByArea && !viewModel.isReverseGeocoding
        return Button {
            let meters = distanceMeters(from: userStartCoordinate, to: lastCenter)
            if meters > 200 {
                showFarLocationAlert = true
            } else if shouldOpenSaveSheetAfterAreaCheck() {
                showSaveSheet = true
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(usePrimary ? DobbyPureScale.onyx : Color(.systemGray3))
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .disabled(!canConfirmByArea || viewModel.isReverseGeocoding)
        .opacity(viewModel.isReverseGeocoding ? 0.65 : 1)
    }

    // MARK: - Save sheet (Android `ModalBottomSheet`)

    private enum SaveAddressSheetPalette {
        static let accent = Color.black
        static let subtitle = Color(red: 0.45, green: 0.45, blue: 0.48)
        static let fieldBorder = Color(red: 0.88, green: 0.88, blue: 0.90)
        static let chipSelectedBg = Color(red: 0.96, green: 0.96, blue: 0.97)
        static let chipBorder = Color(red: 0.90, green: 0.90, blue: 0.92)
    }

    /// Grid order matches redesigned bottom sheet (Casa / Amor / Apartamento | Fiesta / Trabajo).
    private let addressLabelGridColumns: [[String]] = [
        ["Casa", "Amor", "Apartamento"],
        ["Fiesta", "Trabajo"],
    ]

    private let saveSheetCornerRadius: CGFloat = 28

    private var saveAddressSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Guardar dirección")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 22)

                Text("Dirección")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(SaveAddressSheetPalette.accent)
                        .padding(.top, 1)
                    TextField(
                        "Calle, número, colonia",
                        text: $sheetAddress,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SaveAddressSheetPalette.fieldBorder, lineWidth: 1)
                )
                .padding(.bottom, 16)

                Text("Descripción")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)

                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(SaveAddressSheetPalette.accent)
                    TextField("ej. Casa verde, piso 2, int 15", text: $sheetDescription)
                        .textFieldStyle(.plain)
                        .font(.body)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SaveAddressSheetPalette.fieldBorder, lineWidth: 1)
                )
                .padding(.bottom, 22)

                Text("Etiqueta")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 10)

                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(addressLabelGridColumns.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: 10) {
                            ForEach(column, id: \.self) { option in
                                labelChipRow(option: option)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 20)

                if let err = viewModel.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }

                HStack(spacing: 12) {
                    Button {
                        showSaveSheet = false
                    } label: {
                        Text("Cancelar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SaveAddressSheetPalette.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(SaveAddressSheetPalette.accent, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaving)

                    Button {
                        let desc = sheetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.saveAddress(
                            label: sheetSelectedLabel,
                            description: desc.isEmpty ? nil : desc,
                            addressText: sheetAddress,
                            latitude: lastCenter.latitude,
                            longitude: lastCenter.longitude
                        ) {
                            showSaveSheet = false
                            onSaveSuccess()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text(viewModel.isSaving ? "Guardando…" : "Guardar")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(SaveAddressSheetPalette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        viewModel.isSaving ||
                        sheetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SaveAddressSheetHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(SaveAddressSheetHeightKey.self) { height in
            let maxHeight = UIScreen.main.bounds.height * 0.92
            // Drag indicator + safe area breathing room.
            let fitted = min(height + 28, maxHeight)
            if abs(fitted - saveSheetContentHeight) > 1 {
                saveSheetContentHeight = fitted
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: saveSheetCornerRadius, style: .continuous))
    }

    private func labelOptionIcon(_ option: String) -> String {
        switch option {
        case "Casa": return "house.fill"
        case "Apartamento": return "building.2.fill"
        case "Trabajo": return "briefcase.fill"
        case "Amor", "Novia": return "heart.fill"
        case "Fiesta": return "party.popper.fill"
        default: return "mappin.and.ellipse"
        }
    }

    private func labelChipRow(option: String) -> some View {
        let selected = sheetSelectedLabel == option
        return Button {
            sheetSelectedLabel = option
        } label: {
            HStack(spacing: 10) {
                Image(systemName: labelOptionIcon(option))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SaveAddressSheetPalette.accent)
                    .frame(width: 22)
                Text(option)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(selected ? SaveAddressSheetPalette.accent : SaveAddressSheetPalette.chipBorder, lineWidth: selected ? 0 : 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(SaveAddressSheetPalette.accent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(selected ? SaveAddressSheetPalette.chipSelectedBg : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? SaveAddressSheetPalette.accent : SaveAddressSheetPalette.chipBorder, lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SaveAddressSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
