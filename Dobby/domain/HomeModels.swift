//
//  HomeModels.swift
//  Dobby
//

import Foundation
import UIKit

/// Shared sizing for home “Best sellers” cards and shop product grid so tiles match.
enum HomeProductCardLayout {
    /// Same formula as `HomeTabScreen` horizontal `UniversalProductCard` width.
    static func cardWidth(screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGFloat {
        max(88, (screenWidth - 52) / 3.15)
    }

    static let shopGridHorizontalPadding: CGFloat = 18
}

struct FeaturedPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let imageUrl: String?
    let typeLabel: String
    let isService: Bool
    let rate: Float
}

struct BestSellerProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let imageUrl: String?
    let price: Double
    let rate: Float
    let hasPromotion: Bool
    let discount: Int
}

/// Parity with Android `com.ares.ewe.domain.model.ShopProduct` (`app/shops/{id}/products`).
struct ShopProduct: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let price: Double
    let imageUrl: String?
    let rate: Float
    let hasPromotion: Bool
    let discount: Int
}

/// Parity with Android `com.ares.ewe.domain.model.FavoriteProduct`.
struct FavoriteProduct: Identifiable, Hashable, Sendable {
    let productId: String
    let name: String
    let price: Double
    let imageUrl: String?
    let rate: Float
    let hasPromotion: Bool
    let discount: Int

    var id: String { productId }

    func toBestSellerProduct() -> BestSellerProduct {
        BestSellerProduct(
            id: productId,
            name: name,
            imageUrl: imageUrl,
            price: price,
            rate: rate,
            hasPromotion: hasPromotion,
            discount: discount
        )
    }
}

/// From `GET app/products/:id` (parity with Android `ProductDetail`).
struct ProductDetail: Sendable {
    let id: String
    let name: String
    let description: String?
    let price: Double
    let imageUrls: [String]
    let rate: Float
    let hasPromotion: Bool
    let discount: Int
}

/// Payload for `NavigationStack` product detail (home best sellers + shop grid).
struct ProductDetailRoute: Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let imageUrl: String?
    let price: Double
    let rate: Float
    let hasPromotion: Bool
    let discount: Int

    init(bestSeller: BestSellerProduct) {
        id = bestSeller.id
        name = bestSeller.name
        description = nil
        imageUrl = bestSeller.imageUrl
        price = bestSeller.price
        rate = bestSeller.rate
        hasPromotion = bestSeller.hasPromotion
        discount = bestSeller.discount
    }

    init(shopProduct: ShopProduct) {
        id = shopProduct.id
        name = shopProduct.name
        description = shopProduct.description
        imageUrl = shopProduct.imageUrl
        price = shopProduct.price
        rate = shopProduct.rate
        hasPromotion = shopProduct.hasPromotion
        discount = shopProduct.discount
    }

    init(favorite: FavoriteProduct) {
        id = favorite.productId
        name = favorite.name
        description = nil
        imageUrl = favorite.imageUrl
        price = favorite.price
        rate = favorite.rate
        hasPromotion = favorite.hasPromotion
        discount = favorite.discount
    }

    /// Single-unit price after promotion discount (matches product detail screen).
    var unitPriceAfterDiscount: Double {
        let vd = max(0, min(100, discount))
        if hasPromotion && vd > 0 {
            return price * (1 - Double(vd) / 100)
        }
        return price
    }
}

/// One row in the local shopping cart (until a cart API exists).
struct CartLineItem: Identifiable, Hashable, Sendable {
    let productId: String
    var name: String
    var imageUrl: String?
    var quantity: Int
    /// Unit price after promotion (what the customer pays per unit).
    var unitPrice: Double
    /// List / original unit price from the API (`price` before discount).
    var listUnitPrice: Double
    var hasPromotion: Bool
    var discount: Int

    var id: String { productId }

    var lineTotal: Double {
        Double(quantity) * unitPrice
    }

    /// What the line would cost at list price (for strikethrough when `hasPromotion`).
    var lineTotalAtListPrice: Double {
        Double(quantity) * listUnitPrice
    }
}

struct HomeData: Sendable {
    let featuredPlaces: [FeaturedPlace]
    let bestSellerProducts: [BestSellerProduct]
}

struct Ad: Identifiable, Hashable {
    let id: String
    let imageUrl: String?
    let name: String
    let description: String?
    let address: String?
    let contactPhone: String?
    let whatsapp: String?
    let email: String?
    let facebookUrl: String?
    let instagramUrl: String?
}
