//
//  AddressSearchRegion.swift
//  Dobby
//
//  Región fija para autocomplete de direcciones (paridad Android).
//  Por ahora solo Tala; cuando se amplíe el servicio, cambia estos valores.
//

import Foundation

enum AddressSearchRegion {
    /// Plaza principal de Tala, Jalisco.
    static let centerLat = 20.6507582
    static let centerLng = -103.7029606

    /// Radio estricto (~cubre el municipio de Tala).
    static let radiusMeters = 12_000

    /// Sufijo estilo Google Maps para acotar la búsqueda local.
    static let queryLocality = "Tala, Jalisco"

    static func localizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if trimmed.lowercased().contains("tala") { return trimmed }
        return "\(trimmed), \(queryLocality)"
    }
}
