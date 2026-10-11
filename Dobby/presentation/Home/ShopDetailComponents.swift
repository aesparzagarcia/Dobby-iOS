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
private let shopDetailProductImageAspectRatio: CGFloat = 4 / 3

struct ShopDetailSearchBar: View {
    @Binding var query: String
    var placeholder: String = "Buscar productos..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(ShopDetailPalette.mutedText)
            TextField(placeholder, text: $query)
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

/// Overlay that drops from the top; swipe/drag up to dismiss. Does not push layout.
struct ShopClosedTopBanner: View {
    let reopensLabel: String?
    var shopStatus: String? = nil
    @Binding var isPresented: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var hasAppeared = false

    private var isHighDemand: Bool {
        HomeShopHours.normalizedOpsStatus(shopStatus) == "HIGH_DEMAND"
    }

    private let closedRed = Color(red: 0.94, green: 0.27, blue: 0.27)
    private let bannerBg = Color(red: 1, green: 0.95, blue: 0.96)
    private let dismissThreshold: CGFloat = -48

    var body: some View {
        if isPresented {
            bannerCard
                .offset(y: (hasAppeared ? 0 : -220) + min(0, dragOffset))
                .gesture(dismissDrag)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .top)
                .onAppear {
                    dragOffset = 0
                    hasAppeared = false
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        hasAppeared = true
                    }
                }
                .onChange(of: isPresented) { _, presented in
                    if presented {
                        dragOffset = 0
                        hasAppeared = false
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            hasAppeared = true
                        }
                    }
                }
        }
    }

    private var bannerCard: some View {
        VStack(spacing: 10) {
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
                    Text(isHighDemand ? "Alta demanda" : "Tienda cerrada")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(closedRed)

                    if !isHighDemand, let reopensLabel {
                        reopensLabelText(reopensLabel)
                    }

                    Text(
                        isHighDemand
                            ? "La tienda no puede recibir pedidos ahora."
                            : "Los productos estarán disponibles cuando la tienda abra."
                    )
                    .font(.caption)
                    .foregroundStyle(ShopDetailPalette.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 36, height: 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(bannerBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = min(12, value.translation.height)
            }
            .onEnded { value in
                let shouldDismiss =
                    value.translation.height <= dismissThreshold
                    || value.predictedEndTranslation.height <= dismissThreshold * 1.4
                if shouldDismiss {
                    withAnimation(.easeIn(duration: 0.2)) {
                        dragOffset = -240
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPresented = false
                        dragOffset = 0
                        hasAppeared = false
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
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
    var shopType: String? = nil
    /// When true (e.g. Más vendidos), show every category chip including restaurant- and shop-only ones.
    var showAllCategories: Bool = false
    let onCategorySelected: (String?) -> Void

    private var chips: [ProductCategory.Chip] {
        showAllCategories ? ProductCategory.allFilterChips : ProductCategory.filterChips(forShopType: shopType)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
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
    var isCarWash: Bool = false
    let onTap: () -> Void
    let onAddTap: () -> Void

    private var validDiscount: Int {
        max(0, min(100, product.discount))
    }

    private var showPromotion: Bool {
        product.hasPromotion && validDiscount > 0
    }

    private var showOptions: Bool {
        product.hasMultiplePresentations && !isCarWash
    }

    private var listPrice: Double {
        product.displayListPrice
    }

    private var discountedPrice: Double {
        showPromotion ? listPrice * (1 - Double(validDiscount) / 100) : listPrice
    }

    private func handleCardTap() {
        onTap()
    }

    var body: some View {
        let scale = shopDetailProductCardScale
        let corner = 16 * scale
        let statusColor = isProductAvailable ? DobbyBrandColor.primary : ShopDetailPalette.closedGray
        let footerBg = isProductAvailable ? ShopDetailPalette.footerBg : ShopDetailPalette.unavailableFooterBg
        let cardShape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        VStack(spacing: 0) {
            productImage(corner: corner)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleCardTap)

            productInfoSection(scale: scale, discountedPrice: discountedPrice)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleCardTap)

            productFooter(scale: scale, statusColor: statusColor, footerBg: footerBg)
        }
        .background(Color.white)
        .clipShape(cardShape)
        .contentShape(cardShape)
        .background {
            cardShape
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .allowsHitTesting(false)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func productInfoSection(scale: CGFloat, discountedPrice: Double) -> some View {
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
                    Text(
                        showOptions
                            ? String(format: "Desde $%.2f", discountedPrice)
                            : String(format: "$%.2f", discountedPrice)
                    )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    if showPromotion {
                        HStack(spacing: 4) {
                            Text("-\(validDiscount)%")
                                .font(.caption2.weight(.bold))
                            Text(String(format: "$%.2f", listPrice))
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

    @ViewBuilder
    private func productFooter(scale: CGFloat, statusColor: Color, footerBg: Color) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6 * scale) {
                Image(systemName: isCarWash ? "car.fill" : "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 14 * scale))
                Text(isProductAvailable ? "Disponible" : "No disponible")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            Rectangle()
                .fill(statusColor.opacity(0.25))
                .frame(width: 1, height: 18 * scale)
                .allowsHitTesting(false)

            if isProductAvailable {
                Button(action: { if showOptions { onTap() } else { onAddTap() } }) {
                    addRowLabel(scale: scale, color: statusColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ShopDetailAddButtonStyle(tint: statusColor))
            } else {
                addRowLabel(scale: scale, color: statusColor.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 48)
        .background(footerBg)
    }

    private func addRowLabel(scale: CGFloat, color: Color) -> some View {
        HStack(spacing: 6 * scale) {
            if !showOptions {
                Image(systemName: "plus")
                    .font(.system(size: 14 * scale, weight: .semibold))
            }
            Text(showOptions ? "Ver opciones" : "Agregar")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }

    @ViewBuilder
    private func productImage(corner: CGFloat) -> some View {
        Color.clear
            .aspectRatio(shopDetailProductImageAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ZStack {
                    Color.white
                    LoadingRemoteImage(
                        urlString: product.imageUrl,
                        contentMode: .fill,
                        placeholderBackground: .white
                    ) {
                        placeholderMonogram
                    }
                }
                .clipped()
            }
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

private struct ShopDetailAddButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(tint.opacity(configuration.isPressed ? 0.22 : 0))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ProductVariantPicker: View {
    let variants: [ProductVariant]
    let selectedId: String
    var hasPromotion: Bool = false
    var discount: Int = 0
    let onSelect: (ProductVariant) -> Void

    private var validDiscount: Int {
        max(0, min(100, discount))
    }

    private var showPromotion: Bool {
        hasPromotion && validDiscount > 0
    }

    private func unitPrice(for variant: ProductVariant) -> Double {
        showPromotion ? variant.price * (1 - Double(validDiscount) / 100) : variant.price
    }

    var body: some View {
        if variants.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Elige una presentación")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DobbyBrandColor.textPrimary)
                        Text("Selecciona una opción")
                            .font(.caption)
                            .foregroundStyle(ShopDetailPalette.mutedText)
                    }
                    Spacer(minLength: 12)
                    Text("Obligatorio")
                        .font(.caption)
                        .foregroundStyle(ShopDetailPalette.mutedText)
                        .padding(.top, 2)
                }
                .padding(.bottom, 12)
                VStack(spacing: 10) {
                    ForEach(variants) { variant in
                        let isSelected = selectedId == variant.id
                        Button {
                            onSelect(variant)
                        } label: {
                            HStack(spacing: 12) {
                                VariantRadioIndicator(selected: isSelected)
                                Text(variant.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(DobbyBrandColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(format: "$%.2f", unitPrice(for: variant)))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(DobbyBrandColor.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isSelected ? DobbyBrandColor.primary : ShopDetailPalette.cardBorder,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct VariantRadioIndicator: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    selected ? DobbyBrandColor.primary : ShopDetailPalette.mutedText,
                    lineWidth: 2
                )
            if selected {
                Circle()
                    .fill(DobbyBrandColor.primary)
                    .padding(5)
            }
        }
        .frame(width: 22, height: 22)
    }
}
