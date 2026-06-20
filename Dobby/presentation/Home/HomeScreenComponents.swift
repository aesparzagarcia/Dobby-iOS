//
//  HomeScreenComponents.swift
//  Dobby
//
//  Parity with Android `HomeScreenComponents.kt`.
//

import SwiftUI

enum HomeQuickCategory: Hashable {
    case all
    case restaurants
    case shops
    case services
    case offers
}

enum HomeScreenPalette {
    static let primary = DobbyBrandColor.primary
    static let searchBackground = DobbyBrandColor.surfaceMuted
    static let mutedText = DobbyBrandColor.textSecondary
    static let screenBackground = DobbyPureScale.pure
    static let cardSurface = DobbyBrandColor.cardSurface
    static let openGreen = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let closedGray = DobbyBrandColor.textSecondary
    static let cardShadow = DobbyPureScale.onyx.opacity(0.08)
}

func filterPlacesByCategory(_ places: [FeaturedPlace], category: HomeQuickCategory) -> [FeaturedPlace] {
    switch category {
    case .all:
        return places
    case .restaurants:
        return places.filter { !$0.isService && $0.shopType != "SHOP" }
    case .shops:
        return places.filter { !$0.isService && $0.shopType == "SHOP" }
    case .services:
        return places.filter(\.isService)
    case .offers:
        return places
    }
}

private func placeSubtitle(_ place: FeaturedPlace) -> String {
    if place.isService {
        if let cat = PlaceLabels.serviceCategoryLabelEs(place.serviceCategory) {
            return "Servicio • \(cat)"
        }
        return place.typeLabel
    }
    return place.typeLabel
}

// MARK: - Header & search

struct HomeAddressSearchHeader: View {
    let addressLabel: String?
    let address: String?
    @Binding var searchQuery: String
    let onAddressClick: () -> Void
    private let addressCallout: AnyView

    init(
        addressLabel: String?,
        address: String?,
        searchQuery: Binding<String>,
        onAddressClick: @escaping () -> Void,
        @ViewBuilder addressCallout: () -> some View = { EmptyView() }
    ) {
        self.addressLabel = addressLabel
        self.address = address
        self._searchQuery = searchQuery
        self.onAddressClick = onAddressClick
        self.addressCallout = AnyView(addressCallout())
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onAddressClick) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(HomeScreenPalette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Text(addressLabel ?? "Casa")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Text(address ?? "Añade tu dirección")
                            .font(.caption)
                            .foregroundStyle(address != nil ? HomeScreenPalette.mutedText : Color.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .padding(.trailing, 56)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)

            addressCallout

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(HomeScreenPalette.mutedText)
                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Buscar restaurantes, productos o servicios")
                        .foregroundStyle(HomeScreenPalette.mutedText)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(HomeScreenPalette.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(HomeScreenPalette.searchBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(HomeScreenPalette.cardSurface)
    }
}

// MARK: - Category row

struct HomeCategoryRow: View {
    let selected: HomeQuickCategory
    let onCategorySelected: (HomeQuickCategory) -> Void
    var includeOffers: Bool = true
    var scale: CGFloat = HomeLayoutConstants.categoryRowScale
    var spreadToEdges: Bool = false

    private struct Item {
        let category: HomeQuickCategory
        let label: String
        let systemImage: String
    }

    private var items: [Item] {
        var list: [Item] = [
            Item(category: .restaurants, label: "Restaurantes", systemImage: "fork.knife"),
            Item(category: .shops, label: "Tiendas", systemImage: "bag.fill"),
            Item(category: .services, label: "Servicios", systemImage: "wrench.and.screwdriver.fill"),
        ]
        if includeOffers {
            list.append(Item(category: .offers, label: "Ofertas", systemImage: "tag.fill"))
        }
        list.append(Item(category: .all, label: "Ver todos", systemImage: "square.grid.2x2.fill"))
        return list
    }

    var body: some View {
        let s = scale
        let itemWidth = 78 * s
        let edgePadding = 16 * s

        Group {
            if spreadToEdges {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.label) { index, item in
                        categoryItemButton(item: item, scale: s, itemWidth: itemWidth)
                        if index < items.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, edgePadding)
                .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12 * s) {
                        ForEach(items, id: \.label) { item in
                            categoryItemButton(item: item, scale: s, itemWidth: itemWidth)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(DobbyPureScale.pure)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func categoryItemButton(item: Item, scale s: CGFloat, itemWidth: CGFloat) -> some View {
        let isSelected = selected == item.category
        let boxBackground = isSelected ? DobbyPureScale.pure : DobbyPureScale.onyx
        let iconColor = isSelected ? DobbyPureScale.onyx : DobbyPureScale.pure
        Button {
            onCategorySelected(item.category)
        } label: {
            VStack(spacing: 6 * s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                        .fill(boxBackground)
                        .frame(width: 56 * s, height: 56 * s)
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                                    .stroke(DobbyPureScale.onyx, lineWidth: 2 * s)
                            }
                        }
                    Image(systemName: item.systemImage)
                        .font(.system(size: 26 * s))
                        .foregroundStyle(iconColor)
                }
                Text(item.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? DobbyPureScale.onyx : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: itemWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section header

struct HomeSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(DobbyPureScale.pure)
    }
}

// MARK: - Rating

struct HomeRatingDisplay: View {
    let rate: Float
    var ratingCount: Int?

    private var ratingLabel: String {
        let countSuffix = (ratingCount.flatMap { $0 > 0 ? " (\($0))" : nil }) ?? ""
        return String(format: "%.1f", min(max(rate, 0), 5)) + countSuffix
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
            Text(ratingLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Featured place card

struct HomeFeaturedPlaceCard: View {
    let place: FeaturedPlace
    let width: CGFloat
    let onTap: () -> Void
    var cardScale: CGFloat = HomeLayoutConstants.featuredPlaceCardScale

    private var scale: CGFloat { cardScale }
    private var corner: CGFloat { 16 * scale }
    private var imageHeight: CGFloat { width / (1.65 / max(scale, 0.8)) }

    var body: some View {
        let isOpen = HomeShopHours.isPlaceOpenNow(openingHour: place.openingHour, closingHour: place.closingHour)
        let hoursLabel = HomeShopHours.formatPlaceHoursRange(openingHour: place.openingHour, closingHour: place.closingHour)

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    featuredImage
                        .frame(width: width, height: imageHeight)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: corner,
                                topTrailingRadius: corner
                            )
                        )
                    if let isOpen {
                        Text(isOpen ? "Abierto" : "Cerrado")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6 * scale)
                            .padding(.vertical, 2 * scale)
                            .background(isOpen ? HomeScreenPalette.openGreen : HomeScreenPalette.closedGray)
                            .clipShape(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous))
                            .padding(6 * scale)
                    }
                }

                Text(place.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 10 * scale)
                    .padding(.top, 6 * scale)

                Text(placeSubtitle(place))
                    .font(.caption)
                    .foregroundStyle(HomeScreenPalette.mutedText)
                    .lineLimit(1)
                    .padding(.horizontal, 10 * scale)

                HStack(spacing: 6 * scale) {
                    HomeRatingDisplay(rate: place.rate)
                    if let hoursLabel {
                        HStack(spacing: 4 * scale) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(HomeScreenPalette.mutedText)
                            Text(hoursLabel)
                                .font(.caption)
                                .foregroundStyle(HomeScreenPalette.mutedText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 4 * scale)
                .padding(.bottom, 8 * scale)
            }
            .frame(width: width)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: HomeScreenPalette.cardShadow, radius: cardScale >= 1 ? 3 : 4, x: 0, y: 2)
            .padding(.vertical, cardScale >= 1 ? 0 : 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var featuredImage: some View {
        LoadingRemoteImage(urlString: place.imageUrl) {
            placeholderMonogram
        }
    }

    private var placeholderMonogram: some View {
        Text(String(place.name.prefix(1)).uppercased())
            .font(.title2.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - See more cards

struct HomeFeaturedSeeMoreCard: View {
    let width: CGFloat
    let onTap: () -> Void
    var cardScale: CGFloat = HomeLayoutConstants.featuredPlaceCardScale

    private var scale: CGFloat { cardScale }
    private var corner: CGFloat { 16 * scale }
    private var cardHeight: CGFloat {
        HomeLayoutConstants.featuredPlaceCardHeight(width: width, cardScale: cardScale)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8 * scale) {
                Image(systemName: "square.grid.2x2.fill")
                Text("Ver más")
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(HomeScreenPalette.primary)
            .frame(width: width, height: cardHeight)
            .background(DobbyPureScale.pure)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: HomeScreenPalette.cardShadow, radius: cardScale >= 1 ? 3 : 4, x: 0, y: 2)
            .padding(.vertical, cardScale >= 1 ? 0 : 6)
        }
        .buttonStyle(.plain)
    }
}

struct HomeProductSeeMoreCard: View {
    let width: CGFloat
    let onTap: () -> Void

    private let scale = HomeLayoutConstants.productCardScale
    private var corner: CGFloat { 16 * scale }
    /// Same square image area as [UniversalProductCard].
    private var imageHeight: CGFloat { width }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: width, height: imageHeight)

                    productCardFooterPlaceholder
                }

                HStack(spacing: 8 * scale) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Ver más").font(.caption.weight(.bold))
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(HomeScreenPalette.primary)
            }
            .frame(width: width)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: HomeScreenPalette.cardShadow, radius: 4, x: 0, y: 2)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    /// Invisible footer matching [UniversalProductCard] so «Ver más» aligns in the carousel.
    private var productCardFooterPlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{00A0}")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 10 * scale)
                .padding(.top, 8 * scale)

            HStack(spacing: 6 * scale) {
                Text("\u{00A0}")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                HomeRatingDisplay(rate: 0)
            }
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 3 * scale)
            .padding(.bottom, 10 * scale)
        }
        .opacity(0)
    }
}

// MARK: - Service row

struct HomeServicePlaceRow: View {
    let place: FeaturedPlace
    let onTap: () -> Void

    private var category: String {
        PlaceLabels.serviceCategoryLabelEs(place.serviceCategory) ?? place.typeLabel
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                serviceImage
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(HomeScreenPalette.mutedText)
                        .lineLimit(1)
                    HomeRatingDisplay(rate: place.rate)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 260)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.91, blue: 0.93), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var serviceImage: some View {
        LoadingRemoteImage(urlString: place.imageUrl) {
            Text(String(place.name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(HomeScreenPalette.primary)
        }
    }
}

// MARK: - Promo banner

struct HomePromoBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Envío gratis en tu primer pedido")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("Pide ahora y recibe tu pedido sin costo de envío")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(HomeScreenPalette.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - Cart badge

struct HomeCartIconBadge: View {
    let count: Int

    var body: some View {
        // Badge must stay inside these bounds — toolbar Buttons clip overflow (same as Android IconButton).
        ZStack(alignment: .topTrailing) {
            Image(systemName: "cart.fill")
                .font(.system(size: 22))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)

            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, count > 99 ? 4 : 0)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(HomeScreenPalette.primary)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 4)
        .padding(.trailing, 6)
    }
}
