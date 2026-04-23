//
//  CartScreen.swift
//  Dobby
//

import SwiftUI

private enum CartPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let screenBackground = Color(red: 0.97, green: 0.96, blue: 0.98)
    static let rowBackground = Color(red: 0.93, green: 0.91, blue: 0.96)
}

/// Placeholder copy until delivery / payment APIs exist.
private enum CartFakeData {
    static let details = "Torre de departamentos verde int 2"
    static let estimatedDelivery = "30–45 min"
    static let paymentMethod = "Pago contra entrega"
}

struct CartScreen: View {
    @Bindable var viewModel: HomeTabViewModel
    let onBack: () -> Void
    var onPay: () -> Void

    var body: some View {
        ZStack {
            CartPalette.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.cartLines.isEmpty {
                        Text("Tu carrito está vacío.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.cartLines) { line in
                            cartLineRow(line)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        infoRow(
                            label: viewModel.addressLabel ?? "Casa",
                            icon: "mappin.circle.fill",
                            text: viewModel.address ?? "Añade una dirección de entrega"
                        )
                        Divider().padding(.leading, 16)
                        infoRow(
                            label: "Detalles",
                            icon: "info.circle.fill",
                            text: CartFakeData.details
                        )
                        Divider().padding(.leading, 16)
                        infoRow(
                            label: "Entrega estimada",
                            icon: "clock.fill",
                            text: CartFakeData.estimatedDelivery
                        )
                        Divider().padding(.leading, 16)
                        infoRow(
                            label: "Método de pago",
                            icon: "creditcard.fill",
                            text: CartFakeData.paymentMethod
                        )
                    }
                    .padding(.top, 24)
                    .background(Color.white.opacity(0.5))

                    HStack {
                        Text("Total")
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text(money(viewModel.cartTotal))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(CartPalette.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    Button {
                        onPay()
                    } label: {
                        Text("Pagar \(money(viewModel.cartTotal))")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CartPalette.primary)
                    .disabled(viewModel.cartLines.isEmpty || viewModel.cartTotal <= 0)
                    .opacity(viewModel.cartLines.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("Carrito")
        .navigationBarTitleDisplayMode(.large)
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
    }

    private func cartLineRow(_ line: CartLineItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            cartThumb(line)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
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
        .padding(12)
        .background(CartPalette.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 10)
    }

    private func cartThumb(_ line: CartLineItem) -> some View {
        Group {
            if let url = line.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    default:
                        Color(.systemGray5)
                    }
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    Text(String(line.name.prefix(1)).uppercased())
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func infoRow(label: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .padding(.vertical, 12)
    }

    private func money(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
