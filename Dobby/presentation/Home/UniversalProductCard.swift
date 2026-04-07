//
//  UniversalProductCard.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.home.UniversalProductCard`.
//

import SwiftUI

enum UniversalProductCardPalette {
    /// Same accent as `HomeTabScreen` / shop product tiles.
    static let accent = Color(red: 0.45, green: 0.35, blue: 0.75)
}

/// Horizontal product tile (best sellers, promotions, etc.).
struct UniversalProductCard: View {
    let product: BestSellerProduct
    let width: CGFloat

    private let cardRadius: CGFloat = 14

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
                    .frame(width: width, height: width)
                    .clipped()

                if showPromotion {
                    productCardDiscountLabel(
                        validDiscount: validDiscount,
                        originalPrice: product.price
                    )
                    .padding(.bottom, 12)
                }
            }
            .frame(width: width, height: width)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "$%.2f", discountedPrice))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(product.name)
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(alignment: .center, spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(UniversalProductCardPalette.accent)
                    Text(String(format: "%.1f", product.rate))
                        .font(.caption2)
                        .foregroundStyle(Color(white: 0.25))
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
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
                            .frame(width: width, height: width)
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
