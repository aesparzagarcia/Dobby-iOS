//
//  ShopDetailComponents.swift
//  Dobby
//
//  Parity with Android `ShopDetailComponents.kt`.
//

import SwiftUI

private enum ShopDetailPalette {
    static let searchBg = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let mutedText = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let cardBorder = Color(red: 0.91, green: 0.91, blue: 0.93)
    static let promoOrange = Color(red: 1, green: 0.54, blue: 0.24)
    static let footerBg = Color(red: 0.96, green: 0.95, blue: 1)
    static let unavailableFooterBg = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let closedGray = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let imagePlaceholder = Color(red: 0.95, green: 0.96, blue: 0.97)
}

private let shopDetailProductCardScale: CGFloat = 0.9

struct ShopDetailSearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(ShopDetailPalette.mutedText)
            TextField("Buscar productos...", text: $query)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ShopDetailPalette.searchBg)
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }
}

struct ShopClosedBanner: View {
    let reopensLabel: String?

    private let closedRed = Color(red: 0.94, green: 0.27, blue: 0.27)
    private let bannerBg = Color(red: 1, green: 0.95, blue: 0.96)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(closedRed)
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tienda cerrada")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(closedRed)

                if let reopensLabel {
                    reopensLabelText(reopensLabel)
                }

                Text("Los productos estarán disponibles cuando la tienda abra.")
                    .font(.caption)
                    .foregroundStyle(ShopDetailPalette.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(bannerBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func reopensLabelText(_ label: String) -> some View {
        let prefix = "Abre hoy a las "
        if label.hasPrefix(prefix) {
            let time = String(label.dropFirst(prefix.count))
            (
                Text(prefix)
                    .foregroundStyle(ShopDetailPalette.mutedText)
                +
                Text(time)
                    .foregroundStyle(closedRed)
                    .fontWeight(.semibold)
            )
            .font(.caption)
        } else {
            Text(label)
                .font(.caption)
                .foregroundStyle(ShopDetailPalette.mutedText)
        }
    }
}

private struct ShopClosedStoreIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2)
                              ? Color(red: 0.98, green: 0.66, blue: 0.83)
                              : Color(red: 0.99, green: 0.95, blue: 0.97))
                        .frame(height: 10)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(red: 0.99, green: 0.91, blue: 0.95))
                Text("CERRADO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.94, green: 0.27, blue: 0.27))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

struct ShopDetailCategoryRow: View {
    let selectedCategoryId: String?
    let onCategorySelected: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProductCategory.filterChips) { chip in
                    let selected = selectedCategoryId == chip.filterId
                    Button {
                        onCategorySelected(chip.filterId)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: chip.systemImage)
                                .font(.system(size: 14))
                            Text(chip.label)
                                .font(.subheadline.weight(selected ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background {
                            if selected {
                                Capsule().fill(DobbyBrandColor.primary)
                            } else {
                                Capsule()
                                    .fill(Color.white)
                                    .overlay(Capsule().stroke(ShopDetailPalette.cardBorder, lineWidth: 1))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct ShopDetailProductCard: View {
    let product: ShopProduct
    let isProductAvailable: Bool
    let onTap: () -> Void
    let onAddTap: () -> Void

    private var validDiscount: Int {
        max(0, min(100, product.discount))
    }

    private var showPromotion: Bool {
        product.hasPromotion && validDiscount > 0
    }

    private var discountedPrice: Double {
        showPromotion ? product.price * (1 - Double(validDiscount) / 100) : product.price
    }

    var body: some View {
        let scale = shopDetailProductCardScale
        let corner = 16 * scale
        let statusColor = isProductAvailable ? DobbyBrandColor.primary : ShopDetailPalette.closedGray
        let footerBg = isProductAvailable ? ShopDetailPalette.footerBg : ShopDetailPalette.unavailableFooterBg

        VStack(spacing: 0) {
            Button(action: onTap) {
                productImage(height: 180 * scale, corner: corner)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(product.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(product.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .font(.caption)
                        .foregroundStyle(ShopDetailPalette.mutedText)
                        .lineLimit(2)
                        .padding(.top, 4 * scale)

                    Divider()
                        .overlay(ShopDetailPalette.cardBorder)
                        .padding(.vertical, 10 * scale)

                    HStack(alignment: .center) {
                        HStack(spacing: 8 * scale) {
                            Text(String(format: "$%.2f", discountedPrice))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)

                            if showPromotion {
                                HStack(spacing: 4) {
                                    Text("-\(validDiscount)%")
                                        .font(.caption2.weight(.bold))
                                    Text(String(format: "$%.2f", product.price))
                                        .font(.caption2)
                                        .strikethrough()
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ShopDetailPalette.promoOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }

                        Spacer(minLength: 8)

                        HomeRatingDisplay(rate: product.rate, ratingCount: product.ratingCount)
                    }
                }
                .padding(.horizontal, 14 * scale)
                .padding(.vertical, 12 * scale)
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.system(size: 14 * scale))
                    Text(isProductAvailable ? "Disponible" : "No disponible")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(statusColor)
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(statusColor.opacity(0.25))
                    .frame(width: 1, height: 18 * scale)

                Group {
                    if isProductAvailable {
                        Button(action: onAddTap) {
                            addRowLabel(scale: scale, color: statusColor)
                        }
                        .buttonStyle(.plain)
                    } else {
                        addRowLabel(scale: scale, color: statusColor.opacity(0.45))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10 * scale)
            .background(footerBg)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func addRowLabel(scale: CGFloat, color: Color) -> some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "plus")
                .font(.system(size: 14 * scale, weight: .semibold))
            Text("Agregar")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func productImage(height: CGFloat, corner: CGFloat) -> some View {
        ZStack {
            ShopDetailPalette.imagePlaceholder
            if let urlString = product.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderMonogram
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderMonogram
                    }
                }
            } else {
                placeholderMonogram
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: corner,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner,
                style: .continuous
            )
        )
    }

    private var placeholderMonogram: some View {
        Text(String(product.name.prefix(1)).uppercased())
            .font(.title2.weight(.medium))
            .foregroundStyle(.secondary)
    }
}
