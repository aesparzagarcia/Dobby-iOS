//
//  CartShopSwitchPolicy.swift
//  Dobby
//

import Foundation

enum CartShopSwitchPolicy {
    static func needsConfirmation(lines: [CartLineItem], targetShopId: String) -> Bool {
        if lines.isEmpty { return false }
        let target = targetShopId.trimmingCharacters(in: .whitespacesAndNewlines)
        if target.isEmpty { return true }
        let cartShopIds = Set(
            lines.compactMap { line -> String? in
                guard let id = line.shopId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !id.isEmpty else { return nil }
                return id
            }
        )
        if cartShopIds.isEmpty { return true }
        return !cartShopIds.allSatisfy { $0 == target }
    }
}
