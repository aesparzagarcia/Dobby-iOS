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
        openingDays: [String] = [],
        openingSchedules: [ShopHourWindow] = []
    ) -> Bool? {
        let windows = resolvedWindows(
            openingHour: openingHour,
            closingHour: closingHour,
            openingDays: openingDays,
            openingSchedules: openingSchedules
        )
        if windows.isEmpty {
            let days = normalizedDays(openingDays)
            let today = weekdayCode(from: Date())
            if days.count < 7, !days.contains(today) { return false }
            return nil
        }
        var knownClosed = false
        for window in windows {
            switch isWindowOpenNow(window) {
            case true?:
                return true
            case false?:
                knownClosed = true
            case nil:
                break
            }
        }
        return knownClosed ? false : nil
    }

    private static func isWindowOpenNow(_ window: ShopHourWindow) -> Bool? {
        let days = normalizedDays(window.days)
        let today = weekdayCode(from: Date())
        guard let open = parseHour(window.open), let close = parseHour(window.close) else {
            if days.count < 7, !days.contains(today) { return false }
            return nil
        }
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

    static func formatPlaceHoursRange(
        openingHour: String?,
        closingHour: String?,
        openingSchedules: [ShopHourWindow] = []
    ) -> String? {
        let windows = resolvedWindows(
            openingHour: openingHour,
            closingHour: closingHour,
            openingDays: [],
            openingSchedules: openingSchedules
        )
        if windows.count > 1 {
            return windows.map { w in
                "\(formatDaysLabel(w.days)) \(formatHour12(w.open)) - \(formatHour12(w.close))"
            }.joined(separator: " · ")
        }
        let open = (windows.first?.open ?? openingHour)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let close = (windows.first?.close ?? closingHour)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        openingDays: [String] = [],
        openingSchedules: [ShopHourWindow] = []
    ) -> Bool {
        if !isOrderableOpsStatus(shopStatus) { return false }
        return isPlaceOpenNow(
            openingHour: openingHour,
            closingHour: closingHour,
            openingDays: openingDays,
            openingSchedules: openingSchedules
        ) != false
    }

    /// e.g. "Abre hoy a las 8:00 AM" or "Abre el lunes a las 8:00 AM".
    static func formatShopReopensLabel(
        shopStatus: String?,
        openingHour: String?,
        openingDays: [String] = [],
        closingHour: String? = nil,
        openingSchedules: [ShopHourWindow] = []
    ) -> String? {
        if !isOrderableOpsStatus(shopStatus) { return nil }
        let windows = resolvedWindows(
            openingHour: openingHour,
            closingHour: closingHour,
            openingDays: openingDays,
            openingSchedules: openingSchedules
        )
        let cal = Calendar.current
        let now = Date()
        if windows.isEmpty {
            let openRaw = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if openRaw.isEmpty { return nil }
            guard parseHour(openRaw) != nil else { return nil }
            let days = normalizedDays(openingDays)
            let today = weekdayCode(from: now)
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
        let today = weekdayCode(from: now)
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let todayShifts = windows
            .filter { normalizedDays($0.days).contains(today) }
            .compactMap { w in parseHour(w.open).map { open in (open, w) } }
            .sorted { lhs, rhs in
                lhs.0.hour * 60 + lhs.0.minute < rhs.0.hour * 60 + rhs.0.minute
            }
        if let next = todayShifts.first(where: { $0.0.hour * 60 + $0.0.minute > nowMinutes }) {
            return "Abre hoy a las \(formatHour12(next.1.open))"
        }
        for offset in 1 ... 7 {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let code = weekdayCode(from: date)
            let dayShifts = windows
                .filter { normalizedDays($0.days).contains(code) }
                .compactMap { w in parseHour(w.open).map { open in (open, w) } }
                .sorted { lhs, rhs in
                    lhs.0.hour * 60 + lhs.0.minute < rhs.0.hour * 60 + rhs.0.minute
                }
            guard let earliest = dayShifts.first else { continue }
            if offset == 1 {
                return "Abre mañana a las \(formatHour12(earliest.1.open))"
            }
            return "Abre el \(weekdayNameEs(code)) a las \(formatHour12(earliest.1.open))"
        }
        if let first = windows.first {
            return "Abre a las \(formatHour12(first.open))"
        }
        return nil
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
            openingDays: shop.openingDays,
            openingSchedules: shop.openingSchedules
        )
    }

    /// Available shops first; preserves sales/API order within each group.
    /// Open/available featured places first; preserves API order within each group.
    static func isFeaturedPlaceAvailable(_ place: FeaturedPlace) -> Bool {
        if place.isService {
            return isPlaceOpenNow(
                openingHour: place.openingHour,
                closingHour: place.closingHour,
                openingDays: place.openingDays,
                openingSchedules: place.openingSchedules
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

    private static func resolvedWindows(
        openingHour: String?,
        closingHour: String?,
        openingDays: [String],
        openingSchedules: [ShopHourWindow]
    ) -> [ShopHourWindow] {
        let fromApi = openingSchedules.compactMap { w -> ShopHourWindow? in
            let open = w.open.trimmingCharacters(in: .whitespacesAndNewlines)
            let close = w.close.trimmingCharacters(in: .whitespacesAndNewlines)
            if open.isEmpty || close.isEmpty { return nil }
            return ShopHourWindow(days: w.days, open: open, close: close)
        }
        if !fromApi.isEmpty { return fromApi }
        let open = openingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let close = closingHour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if open.isEmpty || close.isEmpty { return [] }
        return [ShopHourWindow(days: openingDays, open: open, close: close)]
    }

    private static func formatDaysLabel(_ days: [String]) -> String {
        let selected = weekdayCodes.filter { normalizedDays(days).contains($0) }
        if selected.count == 7 { return "Todos los días" }
        if selected.count == 5, !selected.contains("SAT"), !selected.contains("SUN") {
            return "Lun–Vie"
        }
        return selected.map { code in
            switch code {
            case "MON": return "Lun"
            case "TUE": return "Mar"
            case "WED": return "Mié"
            case "THU": return "Jue"
            case "FRI": return "Vie"
            case "SAT": return "Sáb"
            case "SUN": return "Dom"
            default: return code
            }
        }.joined(separator: ", ")
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
