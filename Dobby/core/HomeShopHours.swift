//
//  HomeShopHours.swift
//  Dobby
//

import Foundation

enum HomeShopHours {
    static let weekdayCodes = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    /// Whether the place is open now; `nil` if hours are unknown.
    static func isPlaceOpenNow(
        openingHour: String?,
        closingHour: String?,
        openingDays: [String] = []
    ) -> Bool? {
        let days = normalizedDays(openingDays)
        let today = weekdayCode(from: Date())
        let hoursKnown = parseHour(openingHour) != nil && parseHour(closingHour) != nil
        if !hoursKnown {
            if days.count < 7, !days.contains(today) { return false }
            return nil
        }
        guard let open = parseHour(openingHour), let close = parseHour(closingHour) else { return nil }
        let now = Date()
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let openMinutes = open.hour * 60 + open.minute
        let closeMinutes = close.hour * 60 + close.minute
        let overnight = closeMinutes < openMinutes
        if overnight {
            if nowMinutes >= openMinutes {
                return days.contains(today)
            }
            let yesterday = weekdayCode(from: cal.date(byAdding: .day, value: -1, to: now) ?? now)
            return days.contains(yesterday)
        }
        if !days.contains(today) { return false }
        return nowMinutes >= openMinutes && nowMinutes < closeMinutes
    }

    static func formatPlaceHoursRange(openingHour: String?, closingHour: String?) -> String? {
        let open = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let close = closingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if open.isEmpty || close.isEmpty { return nil }
        return "\(formatHour12(open)) - \(formatHour12(close))"
    }

    /// AVAILABLE / SLOW can receive orders; HIGH_DEMAND is listed but blocked.
    static func isOrderableOpsStatus(_ shopStatus: String?) -> Bool {
        switch normalizedOpsStatus(shopStatus) {
        case "HIGH_DEMAND", "INACTIVE":
            return false
        default:
            return true
        }
    }

    static func normalizedOpsStatus(_ shopStatus: String?) -> String {
        let raw = (shopStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw == "SLOW" || raw == "LENTO" { return "SLOW" }
        if raw == "HIGH_DEMAND" || raw == "ALTA_DEMANDA" || raw == "ALTADEMANDA" { return "HIGH_DEMAND" }
        if raw == "INACTIVE" { return "INACTIVE" }
        return "AVAILABLE"
    }

    static func shopOpsLabel(_ shopStatus: String?) -> String {
        switch normalizedOpsStatus(shopStatus) {
        case "SLOW": return "Lento"
        case "HIGH_DEMAND": return "Alta demanda"
        default: return "Disponible"
        }
    }

    /// Orders allowed when shop is Disponible/Lento and within opening hours (unknown hours → treat as open).
    static func isShopAvailableForOrders(
        shopStatus: String?,
        openingHour: String?,
        closingHour: String?,
        openingDays: [String] = []
    ) -> Bool {
        if !isOrderableOpsStatus(shopStatus) { return false }
        return isPlaceOpenNow(
            openingHour: openingHour,
            closingHour: closingHour,
            openingDays: openingDays
        ) != false
    }

    /// e.g. "Abre hoy a las 8:00 AM" or "Abre el lunes a las 8:00 AM".
    static func formatShopReopensLabel(
        shopStatus: String?,
        openingHour: String?,
        openingDays: [String] = []
    ) -> String? {
        if !isOrderableOpsStatus(shopStatus) { return nil }
        let openRaw = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if openRaw.isEmpty { return nil }
        guard parseHour(openRaw) != nil else { return nil }
        let days = normalizedDays(openingDays)
        let today = weekdayCode(from: Date())
        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if let open = parseHour(openRaw) {
            let openMinutes = open.hour * 60 + open.minute
            if days.contains(today), nowMinutes < openMinutes {
                return "Abre hoy a las \(formatHour12(openRaw))"
            }
        }
        for offset in 1 ... 7 {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let code = weekdayCode(from: date)
            if days.contains(code) {
                if offset == 1 {
                    return "Abre mañana a las \(formatHour12(openRaw))"
                }
                return "Abre el \(weekdayNameEs(code)) a las \(formatHour12(openRaw))"
            }
        }
        return "Abre a las \(formatHour12(openRaw))"
    }

    /// Home/promotions list items: match shop hours from featured places (ACTIVE shops on `/home`).
    static func isProductShopAvailableForOrders(
        shopId: String?,
        featuredPlaces: [FeaturedPlace]
    ) -> Bool {
        let id = shopId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if id.isEmpty { return false }
        guard let shop = featuredPlaces.first(where: { $0.id == id && !$0.isService }) else {
            return false
        }
        return isShopAvailableForOrders(
            shopStatus: shop.shopStatus,
            openingHour: shop.openingHour,
            closingHour: shop.closingHour,
            openingDays: shop.openingDays
        )
    }

    /// Available shops first; preserves sales/API order within each group.
    /// Open/available featured places first; preserves API order within each group.
    static func isFeaturedPlaceAvailable(_ place: FeaturedPlace) -> Bool {
        if place.isService {
            return isPlaceOpenNow(
                openingHour: place.openingHour,
                closingHour: place.closingHour,
                openingDays: place.openingDays
            ) != false
        }
        return isOrderableOpsStatus(place.shopStatus)
    }

    static func sortFeaturedPlacesByAvailability(places: [FeaturedPlace]) -> [FeaturedPlace] {
        places.enumerated().sorted { lhs, rhs in
            let lhsAvailable = isFeaturedPlaceAvailable(lhs.element)
            let rhsAvailable = isFeaturedPlaceAvailable(rhs.element)
            if lhsAvailable != rhsAvailable { return lhsAvailable && !rhsAvailable }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    static func sortBestSellersByShopAvailability(
        products: [BestSellerProduct],
        featuredPlaces: [FeaturedPlace]
    ) -> [BestSellerProduct] {
        sortProductsByShopAvailability(products: products, featuredPlaces: featuredPlaces) { $0.shopId }
    }

    static func sortShopProductsByShopAvailability(
        products: [ShopProduct],
        featuredPlaces: [FeaturedPlace]
    ) -> [ShopProduct] {
        sortProductsByShopAvailability(products: products, featuredPlaces: featuredPlaces) { $0.shopId }
    }

    private static func sortProductsByShopAvailability<Product>(
        products: [Product],
        featuredPlaces: [FeaturedPlace],
        shopId: (Product) -> String?
    ) -> [Product] {
        products.enumerated().sorted { lhs, rhs in
            let lhsAvailable = isProductShopAvailableForOrders(
                shopId: shopId(lhs.element),
                featuredPlaces: featuredPlaces
            )
            let rhsAvailable = isProductShopAvailableForOrders(
                shopId: shopId(rhs.element),
                featuredPlaces: featuredPlaces
            )
            if lhsAvailable != rhsAvailable { return lhsAvailable && !rhsAvailable }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    private static func normalizedDays(_ raw: [String]) -> Set<String> {
        let cleaned = Set(
            raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { weekdayCodes.contains($0) }
        )
        return cleaned.isEmpty ? Set(weekdayCodes) : cleaned
    }

    /// Gregorian weekday: 1 = Sunday.
    private static func weekdayCode(from date: Date, calendar: Calendar = .current) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let sundayFirst = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return sundayFirst[(index + 7) % 7]
    }

    private static func weekdayNameEs(_ code: String) -> String {
        switch code {
        case "MON": return "lunes"
        case "TUE": return "martes"
        case "WED": return "miércoles"
        case "THU": return "jueves"
        case "FRI": return "viernes"
        case "SAT": return "sábado"
        case "SUN": return "domingo"
        default: return code.lowercased()
        }
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
