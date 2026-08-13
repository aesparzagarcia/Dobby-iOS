//
//  CartShopSwitchPolicy.swift
//  Dobby
//

import Foundation

enum CartShopSwitchPolicy {
    /// Trims and treats blank as missing — empty `""` must not block the `??` fallback chain.
    static func normalized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func needsConfirmation(lines: [CartLineItem], targetShopId: String) -> Bool {
        if lines.isEmpty { return false }
        // Servicios y productos de tienda no se mezclan: vaciar al entrar a una tienda.
        if lines.contains(where: \.isServicePayment) { return true }
        guard let target = normalized(targetShopId) else { return true }
        let cartShopIds = Set(lines.compactMap { normalized($0.shopId) })
        // Legacy rows without shopId: don't block (same-shop false positive). New adds always persist shopId.
        if cartShopIds.isEmpty { return false }
        return !cartShopIds.allSatisfy { $0.caseInsensitiveCompare(target) == .orderedSame }
    }
}
