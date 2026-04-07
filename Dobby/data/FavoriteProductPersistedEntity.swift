//
//  FavoriteProductPersistedEntity.swift
//  Dobby
//
//  SwiftData mirror of Android `FavoriteProductEntity` / Room `favorite_products`.
//

import Foundation
import SwiftData

@Model
final class FavoriteProductPersistedEntity {
    @Attribute(.unique) var productId: String
    var name: String
    var price: Double
    var imageUrl: String?
    var rate: Float
    var hasPromotion: Bool
    var discount: Int
    var createdAt: Date

    init(
        productId: String,
        name: String,
        price: Double,
        imageUrl: String?,
        rate: Float,
        hasPromotion: Bool,
        discount: Int,
        createdAt: Date = Date()
    ) {
        self.productId = productId
        self.name = name
        self.price = price
        self.imageUrl = imageUrl
        self.rate = rate
        self.hasPromotion = hasPromotion
        self.discount = discount
        self.createdAt = createdAt
    }

    convenience init(from product: FavoriteProduct, createdAt: Date = Date()) {
        self.init(
            productId: product.productId,
            name: product.name,
            price: product.price,
            imageUrl: product.imageUrl,
            rate: product.rate,
            hasPromotion: product.hasPromotion,
            discount: product.discount,
            createdAt: createdAt
        )
    }

    func toFavoriteProduct() -> FavoriteProduct {
        FavoriteProduct(
            productId: productId,
            name: name,
            price: price,
            imageUrl: imageUrl,
            rate: rate,
            hasPromotion: hasPromotion,
            discount: discount
        )
    }
}
