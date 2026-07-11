//
//  AdDetailScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.AdDetailScreen`.
//

import SwiftUI
import UIKit

private enum AdDetailPalette {
    static let primary = DobbyBrandColor.primary
}

struct AdDetailScreen: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel: AdDetailViewModel

    let cartItemCount: Int
    let onBack: () -> Void
    let onCartClick: () -> Void

    init(
        adId: String,
        adsRepository: AdsRepository,
        httpClient: DobbyHTTPClient,
        cartItemCount: Int,
        onBack: @escaping () -> Void = {},
        onCartClick: @escaping () -> Void = {}
    ) {
        self.cartItemCount = cartItemCount
        self.onBack = onBack
        self.onCartClick = onCartClick
        _viewModel = State(
            initialValue: AdDetailViewModel(
                adId: adId,
                adsRepository: adsRepository,
                http: httpClient
            )
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            switch (viewModel.uiState.isLoading, viewModel.uiState.ad, viewModel.uiState.errorMessage) {
            case (true, _, _):
                ProgressView()
                    .tint(AdDetailPalette.primary)
            case (false, nil, let err?):
                Text(err)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case (false, nil, nil):
                Text("Anuncio no encontrado")
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case (false, let ad?, _):
                adContent(ad: ad)
            default:
                ProgressView()
                    .tint(AdDetailPalette.primary)
            }
        }
        .navigationTitle(viewModel.uiState.ad?.name ?? "Anuncio")
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
            .hideToolbarSharedBackgroundIfAvailable()
        }
    }

    @ViewBuilder
    private func adContent(ad: Ad) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageHeader(ad: ad)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer().frame(height: 20)

                Text(ad.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)

                if let desc = ad.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                    Spacer().frame(height: 8)
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                if let phone = ad.contactPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
                    Spacer().frame(height: 16)
                    contactCard(
                        icon: "phone.fill",
                        title: "Llamar",
                        value: phone,
                        action: { openDialer(phone: phone) }
                    )
                }

                if let wa = ad.whatsapp?.trimmingCharacters(in: .whitespacesAndNewlines), !wa.isEmpty {
                    Spacer().frame(height: 12)
                    contactCard(
                        icon: nil,
                        title: "WhatsApp",
                        value: wa,
                        action: { openWhatsApp(number: wa) }
                    )
                }

                if let address = ad.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
                    Spacer().frame(height: 12)
                    contactCard(
                        icon: "mappin.circle.fill",
                        title: "Dirección",
                        value: address,
                        action: { openMaps(address: address) }
                    )
                }

                Spacer().frame(height: 24)
            }
        }
    }

    @ViewBuilder
    private func imageHeader(ad: Ad) -> some View {
        LoadingRemoteImage(urlString: ad.imageUrl) {
            placeholderMonogram(name: ad.name)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }

    private func placeholderMonogram(name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.largeTitle.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func contactCard(icon: String?, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AdDetailPalette.primary)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AdDetailPalette.primary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func openDialer(phone: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel:\(digits)") else { return }
        openURL(url)
    }

    private func openWhatsApp(number: String) {
        let digits = number.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits)") else { return }
        openURL(url)
    }

    private func openMaps(address: String) {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        openURL(url)
    }
}
