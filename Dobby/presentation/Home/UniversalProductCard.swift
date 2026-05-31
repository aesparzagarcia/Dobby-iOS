//
//  UniversalProductCard.swift
//  Dobby
//
//  Parity with Android `UniversalProductCard.kt`.
//

import SwiftUI

private let productCardScale: CGFloat = HomeLayoutConstants.productCardScale

/// Horizontal product tile (best sellers, promotions, etc.).
struct UniversalProductCard: View {
    let product: BestSellerProduct
    let width: CGFloat

    private var corner: CGFloat { 16 * productCardScale }
    private var imageHeight: CGFloat { 120 * productCardScale }

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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                imageBlock
                    .frame(width: width, height: imageHeight)
                    .clipped()

                if showPromotion {
                    productCardDiscountLabel(
                        validDiscount: validDiscount,
                        originalPrice: product.price
                    )
                }
            }
            .frame(width: width, height: imageHeight)

            Text(product.name)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10 * productCardScale)
                .padding(.top, 8 * productCardScale)

            HStack(spacing: 6 * productCardScale) {
                Text(String(format: "$%.2f", discountedPrice))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HomeRatingDisplay(rate: product.rate)
            }
            .padding(.horizontal, 10 * productCardScale)
            .padding(.vertical, 3 * productCardScale)
            .padding(.bottom, 10 * productCardScale)
        }
        .frame(width: width)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: HomeScreenPalette.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var imageBlock: some View {
        ZStack {
            Color(.systemGray5)
            if let url = product.imageUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: imageHeight)
                            .clipped()
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
    }

    private var placeholderMonogram: some View {
        Text(String(product.name.prefix(1)).uppercased())
            .font(.title2.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

@ViewBuilder
func productCardDiscountLabel(validDiscount: Int, originalPrice: Double) -> some View {
    HStack(spacing: 0) {
        HStack(spacing: 4) {
            Text("-\(validDiscount)%")
                .font(.caption2.weight(.bold))
            Text(String(format: "$%.2f", originalPrice))
                .font(.caption2)
                .strikethrough()
        }
        .foregroundStyle(.primary)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(Color(red: 1, green: 0.89, blue: 0.3))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 10,
                topTrailingRadius: 10,
                style: .continuous
            )
        )
        Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
