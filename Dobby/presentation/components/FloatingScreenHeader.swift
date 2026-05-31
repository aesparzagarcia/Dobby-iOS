//
//  FloatingScreenHeader.swift
//  Dobby
//
//  Reusable floating top bar (white card, gray back button, centered title, optional cart).
//

import SwiftUI

enum FloatingScreenHeaderStyle {
    static let titleColor = DobbyBrandColor.dark
    static let cartBadgeBackground = DobbyBrandColor.primary
    static let backButtonBackground = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
    static let cardCornerRadius: CGFloat = 18
    static let backButtonCornerRadius: CGFloat = 12
    static let backButtonSize: CGFloat = 40
    static let sideSlotWidth: CGFloat = 48
}

struct FloatingScreenHeader: View {
    let title: String
    let onBack: () -> Void
    var backAccessibilityLabel: String = "Volver"
    var cartItemCount: Int = 0
    var onCartClick: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FloatingScreenHeaderStyle.titleColor)
                    .frame(
                        width: FloatingScreenHeaderStyle.backButtonSize,
                        height: FloatingScreenHeaderStyle.backButtonSize
                    )
                    .background(FloatingScreenHeaderStyle.backButtonBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: FloatingScreenHeaderStyle.backButtonCornerRadius,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(backAccessibilityLabel)
            .frame(width: FloatingScreenHeaderStyle.sideSlotWidth, alignment: .leading)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FloatingScreenHeaderStyle.titleColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Group {
                if let onCartClick {
                    Button(action: onCartClick) {
                        FloatingScreenHeaderCartBadge(count: cartItemCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Carrito")
                }
            }
            .frame(width: FloatingScreenHeaderStyle.sideSlotWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: FloatingScreenHeaderStyle.cardCornerRadius,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct FloatingScreenHeaderCartBadge: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "cart.fill")
                .font(.title2)
                .foregroundStyle(.primary)
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(FloatingScreenHeaderStyle.cartBadgeBackground)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color.gray.opacity(0.2).ignoresSafeArea()
        FloatingScreenHeader(
            title: "Seguimiento del pedido",
            onBack: {},
            onCartClick: {}
        )
        .safeAreaPadding(.top)
    }
}
