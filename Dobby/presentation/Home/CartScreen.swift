//
//  CartScreen.swift
//  Dobby
//

import SwiftUI

private enum CartPalette {
    static let primary = DobbyBrandColor.primary
    static let screenBackground = Color(red: 0.97, green: 0.96, blue: 0.98)
}

/// Placeholder copy until payment API exists.
private enum CartFakeData {
    static let paymentMethod = "Pago contra entrega"
}

struct CartScreen: View {
    @Bindable var viewModel: HomeTabViewModel
    let onBack: () -> Void
    var isLoggedIn: Bool = true
    var onRequireLogin: () -> Void = {}
    var onPay: () -> Void

    var body: some View {
        Group {
            if viewModel.cartLines.isEmpty {
                Text("Tu carrito está vacío.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    cartProductsList
                    deliveryInfoSection
                    cartFooter
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CartPalette.screenBackground)
        .navigationTitle("Carrito")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationBackButton(action: onBack)
            }
        }
        .alert(
            "No se pudo completar el pedido",
            isPresented: Binding(
                get: { viewModel.cartPayError != nil },
                set: { if !$0 { viewModel.cartPayError = nil } }
            )
        ) {
            Button("Entendido") { viewModel.cartPayError = nil }
        } message: {
            Text(viewModel.cartPayError ?? "")
        }
        .task {
            await viewModel.refreshDeliveryPricing()
        }
    }

    private var cartProductsList: some View {
        List {
            ForEach(viewModel.cartLines) { line in
                cartLineRow(line)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.white)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var deliveryInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow(
                label: viewModel.addressLabel ?? "Casa",
                icon: "mappin.circle.fill",
                text: viewModel.address ?? "Añade una dirección de entrega"
            )
            Divider().padding(.leading, 16)
            if let details = viewModel.addressDetails, !details.isEmpty {
                infoRow(
                    label: "Detalles",
                    icon: "info.circle.fill",
                    text: details
                )
                Divider().padding(.leading, 16)
            }
            infoRow(
                label: "Entrega estimada",
                icon: "clock.fill",
                text: viewModel.estimatedDeliveryLabel
            )
            Divider().padding(.leading, 16)
            infoRow(
                label: "Método de pago",
                icon: "creditcard.fill",
                text: CartFakeData.paymentMethod
            )
        }
        .background(Color.white)
    }

    private var cartFooter: some View {
        VStack(spacing: 0) {
            cartPricingFooter
                .padding(.horizontal, 20)
                .padding(.top, 8)

            if isLoggedIn {
                Button {
                    onPay()
                } label: {
                    Text("Pagar \(money(viewModel.grandTotal))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(CartPalette.primary)
                .disabled(!viewModel.hasValidDeliveryAddress)
                .opacity(viewModel.hasValidDeliveryAddress ? 1 : 0.45)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            } else {
                Button {
                    onRequireLogin()
                } label: {
                    Text("Iniciar sesión para pedir")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(CartPalette.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var cartPricingFooter: some View {
        if let pricing = viewModel.orderPricing {
            pricingLine(label: "Subtotal productos", amount: pricing.productsSubtotal)
            pricingLine(label: "Tarifa de servicio", amount: pricing.serviceFee)
            pricingLine(label: "Envío", amount: pricing.delivery.finalDeliveryFee)
            if pricing.delivery.dynamicMultiplier > 1 {
                Text(
                    "Incluye tarifa dinámica (×\(String(format: "%.2f", pricing.delivery.dynamicMultiplier)))"
                )
                .font(.caption)
                .foregroundStyle(CartPalette.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            Divider()
                .padding(.vertical, 8)
        } else if !viewModel.cartLines.isEmpty {
            HStack {
                Text("Subtotal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(money(viewModel.productsSubtotal))
                    .font(.subheadline)
            }
            Text(
                viewModel.hasValidDeliveryAddress
                    ? "No se pudo calcular el envío. La tienda no tiene ubicación válida configurada."
                    : "El costo de envío se calculará al tener una dirección de entrega válida."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }

        HStack {
            Text("Total")
                .font(.headline.weight(.bold))
            Spacer()
            Text(money(viewModel.grandTotal))
                .font(.headline.weight(.bold))
                .foregroundStyle(CartPalette.primary)
        }
        .padding(.top, viewModel.orderPricing == nil && viewModel.cartLines.isEmpty ? 0 : 8)
    }

    private func pricingLine(label: String, amount: Double) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(money(amount))
                .font(.subheadline.weight(.medium))
        }
        .padding(.bottom, 4)
    }

    private func cartLineRow(_ line: CartLineItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            cartThumb(line)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(line.quantity) × \(money(line.unitPrice)) = \(money(line.lineTotal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if line.hasPromotion && line.discount > 0 {
                    HStack(spacing: 6) {
                        Text("-\(line.discount)%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 1, green: 0.89, blue: 0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text(money(line.lineTotalAtListPrice))
                            .font(.caption2)
                            .strikethrough()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.removeCartLine(productId: line.productId)
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(Color(white: 0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quitar \(line.name)")
        }
    }

    private func cartThumb(_ line: CartLineItem) -> some View {
        LoadingRemoteImage(urlString: line.imageUrl) {
            Text(String(line.name.prefix(1)).uppercased())
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(label: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(CartPalette.primary)
                    .frame(width: 22)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private func money(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
