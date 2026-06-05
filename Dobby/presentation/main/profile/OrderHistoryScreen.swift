//
//  OrderHistoryScreen.swift
//  Dobby
//
//  Parity with Android `OrderHistoryScreen`.
//

import SwiftUI

private enum OrderHistoryPalette {
    static let primary = DobbyBrandColor.primary
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let subtle = Color(red: 0.55, green: 0.58, blue: 0.63)
}

struct OrderHistoryScreen: View {
    @Bindable var viewModel: OrderHistoryViewModel
    var onOrderTap: (String) -> Void

    var body: some View {
        Group {
            if viewModel.uiState.isLoading {
                ProgressView()
                    .tint(OrderHistoryPalette.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = viewModel.uiState.errorMessage, !err.isEmpty {
                VStack(spacing: 12) {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OrderHistoryPalette.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.uiState.orders.isEmpty {
                Text("Aún no tienes pedidos")
                    .font(.body)
                    .foregroundStyle(OrderHistoryPalette.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.uiState.orders) { order in
                            Button {
                                onOrderTap(order.id)
                            } label: {
                                orderRow(order)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(DobbyBrandColor.light.ignoresSafeArea())
        .navigationTitle("Mis pedidos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private func orderRow(_ order: OrderHistoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bag.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(OrderHistoryPalette.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(order.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !order.productSummary.isEmpty, order.shopName != nil {
                    Text(order.productSummary)
                        .font(.caption)
                        .foregroundStyle(OrderHistoryPalette.muted)
                        .lineLimit(1)
                }
                Text(formatOrderHistoryDate(order.createdAt))
                    .font(.caption)
                    .foregroundStyle(OrderHistoryPalette.subtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", order.total))
                    .font(.subheadline.weight(.semibold))
                Text(orderStatusLabelEs(order.status))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(OrderHistoryPalette.primary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OrderHistoryPalette.subtle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

private func formatOrderHistoryDate(_ iso: String?) -> String {
    guard let iso, !iso.isEmpty else { return "" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: iso)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: iso)
    }
    guard let date else { return "" }
    let out = DateFormatter()
    out.locale = Locale(identifier: "es_MX")
    out.dateFormat = "d MMM yyyy"
    return out.string(from: date)
}

func orderStatusLabelEs(_ status: String) -> String {
    switch status.uppercased() {
    case "PENDING": return "Pendiente"
    case "CONFIRMED": return "Confirmado"
    case "PREPARING": return "En preparación"
    case "READY_FOR_PICKUP": return "Listo para recoger"
    case "ASSIGNED": return "Asignado"
    case "ON_DELIVERY": return "En camino"
    case "DELIVERED": return "Entregado"
    case "CANCELLED": return "Cancelado"
    default: return status
    }
}
