//
//  CartPersistedEntity.swift
//  Dobby
//
//  SwiftData mirror of Android `CartInfo` / `CartDao` (Room table `cart`).
//

import Foundation
import SwiftData

@Model
final class CartPersistedEntity {
    /// Primary key — matches Android `productId`.
    @Attribute(.unique) var productId: String
    var name: String
    /// Unit price the customer pays (after discount when applicable) — Android `price`.
    var price: Double
    var quantity: Int
    var imageUrl: String?
    /// List price before discount — Android `listPrice`.
    var listPrice: Double
    var hasPromotion: Bool
    var discount: Int
    var pickupLatitude: Double?
    var pickupLongitude: Double?
    var shopId: String?

    init(
        productId: String,
        name: String,
        price: Double,
        quantity: Int,
        imageUrl: String?,
        listPrice: Double,
        hasPromotion: Bool,
        discount: Int,
        pickupLatitude: Double? = nil,
        pickupLongitude: Double? = nil,
        shopId: String? = nil
    ) {
        self.productId = productId
        self.name = name
        self.price = price
        self.quantity = quantity
        self.imageUrl = imageUrl
        self.listPrice = listPrice
        self.hasPromotion = hasPromotion
        self.discount = discount
        self.pickupLatitude = pickupLatitude
        self.pickupLongitude = pickupLongitude
        self.shopId = shopId
    }

    convenience init(from line: CartLineItem) {
        self.init(
            productId: line.productId,
            name: line.name,
            price: line.unitPrice,
            quantity: line.quantity,
            imageUrl: line.imageUrl,
            listPrice: line.listUnitPrice,
            hasPromotion: line.hasPromotion,
            discount: line.discount,
            pickupLatitude: line.pickupLatitude,
            pickupLongitude: line.pickupLongitude,
            shopId: line.shopId
        )
    }

    func toCartLineItem() -> CartLineItem {
        CartLineItem(
            productId: productId,
            name: name,
            imageUrl: imageUrl,
            quantity: quantity,
            unitPrice: price,
            listUnitPrice: listPrice,
            hasPromotion: hasPromotion,
            discount: discount,
            pickupLatitude: pickupLatitude,
            pickupLongitude: pickupLongitude,
            shopId: shopId
        )
    }
}
