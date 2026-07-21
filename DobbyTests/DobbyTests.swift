//
//  DobbyTests.swift
//  DobbyTests
//
//  Created by Armando Esparza Garcia on 02/04/26.
//

import Testing
@testable import Dobby

struct DobbyTests {

    @Test func shopSwitchSkipsSameShop() {
        let lines = [
            CartLineItem(
                productId: "p1",
                name: "Taco",
                imageUrl: nil,
                quantity: 1,
                unitPrice: 10,
                listUnitPrice: 10,
                hasPromotion: false,
                discount: 0,
                shopId: "shop-a"
            )
        ]
        #expect(CartShopSwitchPolicy.needsConfirmation(lines: lines, targetShopId: "shop-a") == false)
        #expect(CartShopSwitchPolicy.needsConfirmation(lines: lines, targetShopId: "SHOP-A") == false)
        #expect(CartShopSwitchPolicy.needsConfirmation(lines: lines, targetShopId: "shop-b") == true)
    }

    @Test func shopSwitchIgnoresBlankShopIdOnLines() {
        let lines = [
            CartLineItem(
                productId: "p1",
                name: "Taco",
                imageUrl: nil,
                quantity: 1,
                unitPrice: 10,
                listUnitPrice: 10,
                hasPromotion: false,
                discount: 0,
                shopId: ""
            )
        ]
        #expect(CartShopSwitchPolicy.needsConfirmation(lines: lines, targetShopId: "shop-a") == false)
        #expect(CartShopSwitchPolicy.normalized("") == nil)
        #expect(CartShopSwitchPolicy.normalized("  ") == nil)
        #expect(CartShopSwitchPolicy.normalized("shop-a") == "shop-a")
    }

}
