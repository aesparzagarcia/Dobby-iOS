//
//  HomeShopHours.swift
//  Dobby
//

import Foundation

enum HomeShopHours {
    /// Whether the place is open now; `nil` if hours are unknown.
    static func isPlaceOpenNow(openingHour: String?, closingHour: String?) -> Bool? {
        guard let open = parseHour(openingHour), let close = parseHour(closingHour) else { return nil }
        let now = Date()
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let openMinutes = open.hour * 60 + open.minute
        let closeMinutes = close.hour * 60 + close.minute
        if closeMinutes > openMinutes || closeMinutes == openMinutes {
            return nowMinutes >= openMinutes && nowMinutes < closeMinutes
        }
        return nowMinutes >= openMinutes || nowMinutes < closeMinutes
    }

    static func formatPlaceHoursRange(openingHour: String?, closingHour: String?) -> String? {
        let open = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let close = closingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if open.isEmpty || close.isEmpty { return nil }
        return "\(formatHour12(open)) - \(formatHour12(close))"
    }

    /// Orders allowed when shop is ACTIVE and within opening hours (unknown hours → treat as open).
    static func isShopAvailableForOrders(
        shopStatus: String?,
        openingHour: String?,
        closingHour: String?
    ) -> Bool {
        if let shopStatus, shopStatus != "ACTIVE" { return false }
        return isPlaceOpenNow(openingHour: openingHour, closingHour: closingHour) != false
    }

    /// e.g. "Abre hoy a las 8:00 AM" when closed outside hours.
    static func formatShopReopensLabel(shopStatus: String?, openingHour: String?) -> String? {
        if let shopStatus, shopStatus != "ACTIVE" { return nil }
        let openRaw = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if openRaw.isEmpty { return nil }
        guard parseHour(openRaw) != nil else { return nil }
        return "Abre hoy a las \(formatHour12(openRaw))"
    }

    private static func parseHour(_ raw: String?) -> (hour: Int, minute: Int)? {
        let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.isEmpty { return nil }
        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return (h, m)
    }

    private static func formatHour12(_ raw: String) -> String {
        guard let t = parseHour(raw) else { return raw }
        let h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour)
        let amPm = t.hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, t.minute, amPm)
    }
}

enum PlaceLabels {
    static func serviceCategoryLabelEs(_ category: String?) -> String? {
        let c = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if c.isEmpty { return nil }
        switch c.uppercased() {
        case "INTERNET": return "Internet"
        case "UTILITIES": return "Servicios públicos"
        case "OTHER": return "Otros"
        default:
            return c.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
