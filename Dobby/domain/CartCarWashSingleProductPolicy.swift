//
//  CartCarWashSingleProductPolicy.swift
//  Dobby
//

import Foundation

/// Autolavado (CAR_WASH) shops only allow one product (quantity 1) per purchase.
enum CartCarWashSingleProductPolicy {
    static let message = "Este comercio acepta un solo producto por compra."

    static func isCarWash(_ shopType: String?) -> Bool {
        guard let type = CartShopSwitchPolicy.normalized(shopType) else { return false }
        return type.caseInsensitiveCompare("CAR_WASH") == .orderedSame
    }

    static func blocksAdd(
        shopType: String?,
        lines: [CartLineItem],
        productId: String,
        shopId: String?,
        quantityToAdd: Int
    ) -> Bool {
        guard isCarWash(shopType) else { return false }
        if quantityToAdd > 1 { return true }
        guard let sid = CartShopSwitchPolicy.normalized(shopId) else {
            return !lines.isEmpty || quantityToAdd > 1
        }
        let fromShop = lines.filter {
            CartShopSwitchPolicy.normalized($0.shopId)?.caseInsensitiveCompare(sid) == .orderedSame
        }
        if fromShop.isEmpty { return false }
        if let existing = fromShop.first(where: { $0.productId == productId }) {
            return existing.quantity + quantityToAdd > 1
        }
        return true
    }
}
