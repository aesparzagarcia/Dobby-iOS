//
//  ServiceDetailScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.ServiceDetailScreen`.
//

import SwiftUI
import UIKit

private enum ServiceDetailPalette {
    static let screenBg = Color(red: 0.969, green: 0.973, blue: 0.969)
    static let cardBorder = Color(red: 0.902, green: 0.910, blue: 0.902)
    static let muted = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let safeGreen = Color(red: 0.106, green: 0.478, blue: 0.239)
    static let safeGreenBg = Color(red: 0.910, green: 0.965, blue: 0.933)
    static let fieldBorder = Color(red: 0.843, green: 0.859, blue: 0.843)
}

struct ServiceDetailScreen: View {
    @State private var viewModel: ServiceDetailViewModel
    @State private var loadedService: ServiceDetail?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var payError: String?
    @State private var showBarcodeScanner = false
    @State private var showAddressRequiredForCartAlert = false
    @State private var pendingScannedDigits: String?

    let cartItemCount: Int
    let onBack: () -> Void
    let onCartClick: () -> Void
    let onPay: (ServiceDetail, String, Double) -> AddToCartResult
    var onNeedsAddress: () -> Void = {}
    var onCancelNeedsAddress: () -> Void = {}

    init(
        serviceId: String,
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onCartClick: @escaping () -> Void = {},
        onPay: @escaping (ServiceDetail, String, Double) -> AddToCartResult = { _, _, _ in .success },
        onNeedsAddress: @escaping () -> Void = {},
        onCancelNeedsAddress: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onCartClick = onCartClick
        self.onPay = onPay
        self.onNeedsAddress = onNeedsAddress
        self.onCancelNeedsAddress = onCancelNeedsAddress
        _viewModel = State(
            initialValue: ServiceDetailViewModel(
                serviceId: serviceId,
                placesRepository: placesRepository,
                http: httpClient
            )
        )
    }

    var body: some View {
        ZStack {
            ServiceDetailPalette.screenBg.ignoresSafeArea()
            content
        }
        .navigationTitle(loadedService?.name ?? "Servicio")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationBackButton(tint: .primary, action: onBack)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCartClick) {
                    HomeCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
            .hideToolbarSharedBackgroundIfAvailable()
        }
        .sheet(isPresented: $showBarcodeScanner) {
            ServiceBarcodeScannerSheet(
                onDigits: { digits in
                    pendingScannedDigits = digits
                },
                onDismiss: { showBarcodeScanner = false }
            )
        }
        .alert("Dirección requerida", isPresented: $showAddressRequiredForCartAlert) {
            Button("Cancelar", role: .cancel) {
                onCancelNeedsAddress()
            }
            Button("Agregar dirección") {
                onNeedsAddress()
            }
        } message: {
            Text("Agrega primero una dirección antes de pagar un servicio.")
        }
        .task {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .tint(DobbyBrandColor.primary)
        } else if let loadError, !loadError.isEmpty, loadedService == nil {
            errorContent(message: loadError)
        } else if let service = loadedService {
            ServiceDetailLoadedContent(
                service: service,
                payError: payError,
                pendingScannedDigits: $pendingScannedDigits,
                onScanBarcode: { showBarcodeScanner = true },
                onPay: handlePay
            )
        } else {
            ProgressView()
                .tint(DobbyBrandColor.primary)
        }
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.body)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Reintentar") {
                reload()
            }
            .buttonStyle(.borderedProminent)
            .tint(DobbyBrandColor.primary)
        }
    }

    private func handlePay(serviceNumber: String, amountText: String) {
        payError = nil
        guard let payload = viewModel.preparePay(
            serviceNumber: serviceNumber,
            amountToPay: amountText
        ) else {
            payError = viewModel.payError
            return
        }
        switch onPay(payload.service, payload.serviceNumber, payload.amount) {
        case .success:
            break
        case .needsAddress:
            showAddressRequiredForCartAlert = true
        case .blockedCarWash:
            break
        }
    }

    private func reload() {
        loadedService = nil
        loadError = nil
        isLoading = true
        Task { await loadIfNeeded(force: true) }
    }

    private func loadIfNeeded(force: Bool = false) async {
        if !force, loadedService != nil { return }
        isLoading = true
        loadError = nil
        switch await viewModel.load() {
        case .success(let service):
            loadedService = service
            isLoading = false
        case .failure(let message):
            loadError = message
            isLoading = false
        }
    }
}

/// Static header + UIKit fields (no SwiftUI TextField).
private struct ServiceDetailLoadedContent: View {
    let service: ServiceDetail
    let payError: String?
    @Binding var pendingScannedDigits: String?
    let onScanBarcode: () -> Void
    let onPay: (String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBlock
            ServicePaymentFormSection(
                serviceName: service.name,
                payError: payError,
                pendingScannedDigits: $pendingScannedDigits,
                onScanBarcode: onScanBarcode,
                onPay: onPay
            )
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            ServiceDetailHeaderCard(service: service)
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(DobbyPureScale.onyx)
                Text(String(format: "%.1f", service.rate))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DobbyBrandColor.textPrimary)
            }
            Text("Información del servicio")
                .font(.title3.weight(.bold))
                .foregroundStyle(DobbyBrandColor.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct ServiceDetailHeaderCard: View {
    let service: ServiceDetail

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            logo
            info
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ServiceDetailPalette.cardBorder, lineWidth: 1)
        )
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.949, green: 0.957, blue: 0.949))
            LoadingRemoteImage(urlString: service.imageUrl) {
                Text(String(service.name.prefix(1)).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DobbyPureScale.onyx)
            }
            .frame(width: 64, height: 64)
            .clipped()
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(DobbyBrandColor.textPrimary)
            if let subtitle = serviceSubtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ServiceDetailPalette.muted)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                Text("Servicio oficial")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(ServiceDetailPalette.safeGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ServiceDetailPalette.safeGreenBg, in: Capsule())
            .padding(.top, 6)
        }
    }

    private var serviceSubtitle: String? {
        if let desc = service.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            return desc
        }
        if let cat = service.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
            return cat
        }
        return nil
    }
}

private struct ServicePaymentFormSection: View {
    let serviceName: String
    let payError: String?
    @Binding var pendingScannedDigits: String?
    let onScanBarcode: () -> Void
    let onPay: (String, String) -> Void

    @State private var draft = ServicePaymentFormDraft()
    @State private var canPay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            numberBlock
            amountBlock
            payBottomBar
        }
    }

    private var numberBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            serviceNumberRow
            Text("Puedes encontrarlo en tu recibo de \(serviceName).")
                .font(.caption)
                .foregroundStyle(ServiceDetailPalette.muted)
        }
    }

    private var serviceNumberRow: some View {
        HStack(spacing: 10) {
            FastUITextField(
                placeholder: "Número de servicio",
                keyboardType: UIKeyboardType.numberPad,
                externalText: pendingScannedDigits,
                onTextChange: handleServiceNumberChange
            )
            .frame(maxWidth: .infinity)
            .frame(height: 28)

            Button(action: onScanBarcode) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18))
                    .foregroundStyle(ServiceDetailPalette.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Escanear código de barras")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ServiceDetailPalette.fieldBorder, lineWidth: 1)
        )
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Importe a pagar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DobbyBrandColor.textPrimary)

            HStack(spacing: 8) {
                Text("$")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DobbyBrandColor.textPrimary)
                FastUITextField(
                    placeholder: "0.00",
                    keyboardType: UIKeyboardType.decimalPad,
                    onTextChange: handleAmountChange
                )
                .frame(maxWidth: .infinity)
                .frame(height: 28)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ServiceDetailPalette.fieldBorder, lineWidth: 1)
            )

            Text("Ingresa el importe exacto a pagar")
                .font(.caption)
                .foregroundStyle(ServiceDetailPalette.muted)
        }
    }

    private var payBottomBar: some View {
        VStack(spacing: 8) {
            if let payError, !payError.isEmpty {
                Text(payError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                onPay(draft.serviceNumber, draft.amountToPay)
            } label: {
                Text("Pagar servicio")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canPay ? Color.white : DobbyPureScale.ash)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canPay ? DobbyPureScale.onyx : DobbyPureScale.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canPay)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
    }

    private func handleServiceNumberChange(_ value: String) {
        if draft.serviceNumber != value {
            draft.serviceNumber = value
            refreshCanPay()
        }
        if pendingScannedDigits != nil {
            DispatchQueue.main.async {
                pendingScannedDigits = nil
            }
        }
    }

    private func handleAmountChange(_ value: String) {
        let filtered = String(value.filter { $0.isNumber || $0 == "." || $0 == "," })
        if draft.amountToPay != filtered {
            draft.amountToPay = filtered
            refreshCanPay()
        }
    }

    private func refreshCanPay() {
        let numberOk = !draft.serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let normalized = draft.amountToPay.replacingOccurrences(of: ",", with: ".")
        let amountOk = Double(normalized).map { $0 > 0 } ?? false
        let next = numberOk && amountOk
        if next != canPay {
            canPay = next
        }
    }
}

private final class ServicePaymentFormDraft {
    var serviceNumber = ""
    var amountToPay = ""
}
