//
//  HomeModels.swift
//  Dobby
//

import Foundation
import UIKit

/// Shared sizing for home “Best sellers” cards and shop product grid so tiles match.
enum HomeProductCardLayout {
    static func featuredCardWidth(screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGFloat {
        HomeLayoutConstants.featuredCardWidth(screenWidth: screenWidth)
    }

    static func cardWidth(screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGFloat {
        HomeLayoutConstants.productCardWidth(featuredWidth: featuredCardWidth(screenWidth: screenWidth))
    }

    static let shopGridHorizontalPadding: CGFloat = 18
}

struct FeaturedPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let imageUrl: String?
    let typeLabel: String
    let isService: Bool
    let shopType: String?
    let serviceCategory: String?
    let rate: Float
    let openingHour: String?
    let closingHour: String?
    let latitude: Double?
    let longitude: Double?
}

struct BestSellerProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let imageUrl: String?
    let price: Double
    let rate: Float
    let hasPromotion: Bool
    let discount: Int
    let shopId: String?
}

/// Parity with Android `com.ares.ewe.domain.model.ShopProduct` (`app/shops/{id}/products`).
struct ShopProduct: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let price: Double
    let imageUrl: String?
    let rate: Float
    let ratingCount: Int
    let hasPromotion: Bool
    let discount: Int
    let shopId: String?
    let category: String?
}

struct ShopProductsPage: Sendable {
    let shopStatus: String
    let openingHour: String?
    let closingHour: String?
    let products: [ShopProduct]
    let shopName: String?
    let shopType: String?
    let logoUrl: String?
    let rate: Float
    let ratingCount: Int
    let jobsDone: Int

    var isShopAvailableForOrders: Bool {
        HomeShopHours.isShopAvailableForOrders(
            shopStatus: shopStatus,
            openingHour: openingHour,
            closingHour: closingHour
        )
    }
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
            discount: discount,
            shopId: nil
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
    let ratingCount: Int
    let hasPromotion: Bool
    let discount: Int
    let shopId: String?
    let shopType: String?
}

/// Parity with Android `ServiceDetail` (`GET app/services/:id`).
struct ServiceDetail: Sendable, Equatable {
    let id: String
    let name: String
    let description: String?
    let imageUrl: String?
    let category: String?
    let rate: Float
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
    let pickupLatitude: Double?
    let pickupLongitude: Double?
    let shopId: String?
    let ratingCount: Int
    let isShopAvailableForOrders: Bool

    init(bestSeller: BestSellerProduct, featuredPlaces: [FeaturedPlace] = []) {
        id = bestSeller.id
        name = bestSeller.name
        description = nil
        imageUrl = bestSeller.imageUrl
        price = bestSeller.price
        rate = bestSeller.rate
        hasPromotion = bestSeller.hasPromotion
        discount = bestSeller.discount
        pickupLatitude = nil
        pickupLongitude = nil
        shopId = CartShopSwitchPolicy.normalized(bestSeller.shopId)
        ratingCount = 0
        isShopAvailableForOrders = HomeShopHours.isProductShopAvailableForOrders(
            shopId: bestSeller.shopId,
            featuredPlaces: featuredPlaces
        )
    }

    init(
        shopProduct: ShopProduct,
        pickupLatitude: Double? = nil,
        pickupLongitude: Double? = nil,
        isShopAvailableForOrders: Bool = true,
        shopIdFallback: String? = nil
    ) {
        id = shopProduct.id
        name = shopProduct.name
        description = shopProduct.description
        imageUrl = shopProduct.imageUrl
        price = shopProduct.price
        rate = shopProduct.rate
        hasPromotion = shopProduct.hasPromotion
        discount = shopProduct.discount
        self.pickupLatitude = pickupLatitude
        self.pickupLongitude = pickupLongitude
        shopId = CartShopSwitchPolicy.normalized(shopProduct.shopId)
            ?? CartShopSwitchPolicy.normalized(shopIdFallback)
        ratingCount = shopProduct.ratingCount
        self.isShopAvailableForOrders = isShopAvailableForOrders
    }

    init(detail: ProductDetail, pickupLatitude: Double? = nil, pickupLongitude: Double? = nil, shopId: String? = nil) {
        id = detail.id
        name = detail.name
        description = detail.description
        imageUrl = detail.imageUrls.first
        price = detail.price
        rate = detail.rate
        hasPromotion = detail.hasPromotion
        discount = detail.discount
        self.pickupLatitude = pickupLatitude
        self.pickupLongitude = pickupLongitude
        self.shopId = CartShopSwitchPolicy.normalized(shopId)
            ?? CartShopSwitchPolicy.normalized(detail.shopId)
        ratingCount = detail.ratingCount
        isShopAvailableForOrders = true
    }

    /// Deep link from promotion push; list fields may come from FCM `data` until `GET app/products/:id` completes.
    init(
        promotionPush productId: String,
        shopId: String?,
        productName: String? = nil,
        discountPercent: Int? = nil,
        isShopAvailableForOrders: Bool = true
    ) {
        id = productId
        let trimmedName = productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = trimmedName.isEmpty ? "Promoción" : trimmedName
        description = nil
        imageUrl = nil
        price = 0
        rate = 0
        let pct = max(0, min(100, discountPercent ?? 0))
        hasPromotion = pct > 0
        discount = pct
        pickupLatitude = nil
        pickupLongitude = nil
        self.shopId = CartShopSwitchPolicy.normalized(shopId)
        ratingCount = 0
        self.isShopAvailableForOrders = isShopAvailableForOrders
    }

    /// Route from push before API returns full product (price still loads from server).
    var isPromotionPushStub: Bool {
        price == 0 && imageUrl == nil
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
        pickupLatitude = nil
        pickupLongitude = nil
        shopId = nil
        ratingCount = 0
        isShopAvailableForOrders = true
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
    /// Tienda de recogida si se añadió desde detalle con coordenadas (ETA en carrito).
    var pickupLatitude: Double?
    var pickupLongitude: Double?
    var shopId: String?

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
    /// 0 = normal … 3 = premium (más apariciones en carrusel).
    let priority: Int
}

/// Slide único en carrusel (anuncios de alta prioridad se repiten más).
struct AdCarouselSlide: Identifiable, Hashable {
    let id: String
    let ad: Ad

    static func weighted(from ads: [Ad]) -> [AdCarouselSlide] {
        let sorted = ads.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.id > rhs.id
        }
        return sorted.flatMap { ad -> [AdCarouselSlide] in
            let weight = min(max(ad.priority, 0), 3) + 1
            return (0 ..< weight).map { index in
                AdCarouselSlide(id: "\(ad.id)-\(index)", ad: ad)
            }
        }
    }
}
