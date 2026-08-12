//
//  AddressDuplicate.swift
//  Dobby
//
//  Parity with Android `AddressDuplicate`.
//

import Foundation

enum AddressDuplicate {
    static let proximityMeters: Double = 50
    static let message = "Esta dirección ya está guardada."

    static func normalizeForCompare(_ address: String) -> String {
        let folded = address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ","))
        let cleaned = String(folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " })
        return cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isDuplicate(
        existing: [UserAddress],
        address: String,
        lat: Double,
        lng: Double
    ) -> Bool {
        let colonyKey = normalizeForCompare(address.addressWithColonyOnly())
        let streetKey = normalizeForCompare(address.streetAndNumberOnly())
        return existing.contains { saved in
            guard saved.isActive else { return false }
            let distance = GeoDistance.haversineMeters(
                lat1: lat, lon1: lng, lat2: saved.lat, lon2: saved.lng
            )
            if distance <= proximityMeters { return true }
            let savedColony = normalizeForCompare(saved.address.addressWithColonyOnly())
            if !colonyKey.isEmpty, colonyKey == savedColony { return true }
            let savedStreet = normalizeForCompare(saved.address.streetAndNumberOnly())
            return !streetKey.isEmpty
                && streetKey == savedStreet
                && distance <= 150
        }
    }
}
