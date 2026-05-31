//
//  ServiceDetailScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.ServiceDetailScreen`.
//

import SwiftUI
import UIKit

private enum ServiceDetailPalette {
    static let primary = DobbyBrandColor.primary
}

struct ServiceDetailScreen: View {
    @State private var viewModel: ServiceDetailViewModel

    let cartItemCount: Int
    let onBack: () -> Void
    let onCartClick: () -> Void

    init(
        serviceId: String,
        placesRepository: PlacesRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onCartClick: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onCartClick = onCartClick
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
            Color(red: 0.97, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            switch (viewModel.uiState.isLoading, viewModel.uiState.errorMessage) {
            case (true, _):
                ProgressView()
                    .tint(ServiceDetailPalette.primary)
            case (false, let err?) where !err.isEmpty:
                VStack(spacing: 16) {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Reintentar") {
                        viewModel.loadService()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ServiceDetailPalette.primary)
                }
            default:
                if let service = viewModel.uiState.service {
                    serviceContent(service: service)
                } else {
                    ProgressView()
                        .tint(ServiceDetailPalette.primary)
                }
            }
        }
        .navigationTitle(viewModel.uiState.service?.name ?? "Servicio")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Atrás")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCartClick) {
                    HomeCartIconBadge(count: cartItemCount)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func serviceContent(service: ServiceDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageHeader(service: service)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer().frame(height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ServiceDetailPalette.primary)
                    Text(String(format: "%.1f", service.rate))
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.25))
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 20)

                if let cat = service.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                    Text(cat)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ServiceDetailPalette.primary)
                        .padding(.horizontal, 16)
                    Spacer().frame(height: 8)
                }

                if let desc = service.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                    Text("Descripción")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                    Spacer().frame(height: 4)
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    Spacer().frame(height: 24)
                } else {
                    Spacer().frame(height: 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Importe a pagar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    TextField("Cantidad o importe ($)", text: Binding(
                        get: { viewModel.uiState.amountToPay },
                        set: { viewModel.onAmountChange($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func imageHeader(service: ServiceDetail) -> some View {
        ZStack {
            Color(.systemGray5)
            if let url = service.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        placeholderMonogram(name: service.name)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderMonogram(name: service.name)
                    }
                }
            } else {
                placeholderMonogram(name: service.name)
            }
        }
    }

    private func placeholderMonogram(name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.largeTitle.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
