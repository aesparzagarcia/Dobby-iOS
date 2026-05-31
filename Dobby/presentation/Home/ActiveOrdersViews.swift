//
//  ActiveOrdersViews.swift
//  Dobby
//
//  Paridad con Android `ActiveOrdersSummaryCard` / `ActiveOrdersScreen`.
//

import SwiftUI

private enum ActiveOrdersPalette {
    static let primary = DobbyBrandColor.primary
}

// MARK: - Home section (0 / 1 / N pedidos)

struct ActiveOrdersHomeSectionView: View {
    let activeOrders: [ActiveOrder]
    var onTrackOrder: (String) -> Void
    var onMultipleOrdersTap: () -> Void

    var body: some View {
        switch activeOrders.count {
        case 0:
            EmptyView()
        case 1:
            OrderTrackingSectionView(activeOrder: activeOrders[0]) {
                onTrackOrder(activeOrders[0].id)
            }
        default:
            ActiveOrdersSummaryCardView(
                activeCount: activeOrders.count,
                onTap: onMultipleOrdersTap
            )
        }
    }
}

// MARK: - Summary card (2+ pedidos)

struct ActiveOrdersSummaryCardView: View {
    let activeCount: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(ActiveOrdersPalette.primary.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: "bag.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(ActiveOrdersPalette.primary)
                    }
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ActiveOrdersPalette.primary)
                        .padding(4)
                        .background(Circle().fill(Color.white))
                        .offset(x: 8, y: 28)

                    Text("\(min(activeCount, 99))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(ActiveOrdersPalette.primary, in: Circle())
                        .offset(x: 10, y: -4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activeCount) pedidos en curso")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Toca para ver el estado de tus entregas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ActiveOrdersPalette.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ActiveOrdersPalette.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lista de pedidos activos

struct ActiveOrdersScreen: View {
    let activeOrders: [ActiveOrder]
    var onTrackOrder: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(activeOrders) { order in
                    OrderTrackingSectionView(
                        activeOrder: order,
                        onViewDetails: { onTrackOrder(order.id) },
                        headerTitle: order.productSummary.isEmpty ? "Tu pedido" : order.productSummary
                    )
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pedidos en curso")
        .navigationBarTitleDisplayMode(.large)
    }
}
