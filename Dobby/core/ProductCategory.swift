//
//  ProductCategory.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.core.util.ProductCategory`.
//

import Foundation

enum ProductCategory {
    static let bebidas = "bebidas"
    static let alcohol = "alcohol"
    static let postres = "postres"
    static let comidas = "comidas"
    static let snacks = "snacks"
    static let miscelaneos = "miscelaneos"
    static let medicamentos = "medicamentos"
    static let otros = "otros"

    static let `default` = miscelaneos

    struct Chip: Identifiable, Hashable {
        let filterId: String?
        let label: String
        let systemImage: String

        var id: String { label }
    }

    /// Best sellers / vistas cruzadas: todas las categorías de filtro.
    static let allFilterChips: [Chip] = [
        Chip(filterId: nil, label: "Todos", systemImage: "square.grid.2x2.fill"),
        Chip(filterId: bebidas, label: "Bebidas", systemImage: "cup.and.saucer.fill"),
        Chip(filterId: alcohol, label: "Alcohol", systemImage: "wineglass.fill"),
        Chip(filterId: comidas, label: "Comidas", systemImage: "fork.knife"),
        Chip(filterId: postres, label: "Postres", systemImage: "birthday.cake.fill"),
        Chip(filterId: medicamentos, label: "Medicamentos", systemImage: "pills.fill"),
        Chip(filterId: otros, label: "Otros", systemImage: "ellipsis"),
    ]

    /// Filtros del detalle de tienda según tipo (`SHOP` vs `RESTAURANT`).
    static func filterChips(forShopType shopType: String?) -> [Chip] {
        let t = shopType?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let isShop = t == "SHOP"
        var chips: [Chip] = [
            Chip(filterId: nil, label: "Todos", systemImage: "square.grid.2x2.fill"),
            Chip(filterId: bebidas, label: "Bebidas", systemImage: "cup.and.saucer.fill"),
            Chip(filterId: alcohol, label: "Alcohol", systemImage: "wineglass.fill"),
        ]
        if isShop {
            chips.append(Chip(filterId: medicamentos, label: "Medicamentos", systemImage: "pills.fill"))
        } else {
            chips.append(Chip(filterId: comidas, label: "Comidas", systemImage: "fork.knife"))
            chips.append(Chip(filterId: postres, label: "Postres", systemImage: "birthday.cake.fill"))
        }
        chips.append(Chip(filterId: otros, label: "Otros", systemImage: "ellipsis"))
        return chips
    }

    static func normalize(_ raw: String?) -> String {
        let slug = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch slug {
        case bebidas, alcohol, postres, comidas, snacks, miscelaneos, medicamentos:
            return slug
        default:
            return `default`
        }
    }

    static func matchesFilter(productCategory: String?, filterId: String?) -> Bool {
        guard let filterId else { return true }
        let normalized = normalize(productCategory)
        switch filterId {
        case otros:
            return normalized == snacks || normalized == miscelaneos
        default:
            return normalized == filterId
        }
    }
}
