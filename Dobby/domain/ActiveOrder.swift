//
//  ActiveOrder.swift
//  Dobby
//
//  Parity with Android `ActiveOrder` / `orderStatusToTrackingStep`.
//

import Foundation

struct ActiveOrderProductLine: Hashable, Sendable {
    let name: String
    let quantity: Int
}

struct ActiveOrder: Identifiable, Hashable, Sendable {
    let id: String
    let status: String
    var total: Double
    var deliveryAddress: String?
    var createdAt: String?
    /// RESTAURANT | SHOP | CAR_WASH | …
    var shopType: String?
    var productLines: [ActiveOrderProductLine]

    init(
        id: String,
        status: String,
        total: Double = 0,
        deliveryAddress: String? = nil,
        createdAt: String? = nil,
        shopType: String? = nil,
        productLines: [ActiveOrderProductLine] = []
    ) {
        self.id = id
        self.status = status
        self.total = total
        self.deliveryAddress = deliveryAddress
        self.createdAt = createdAt
        self.shopType = shopType
        self.productLines = productLines
    }

    var isCarWash: Bool {
        shopType?.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("CAR_WASH") == .orderedSame
    }

    /// Step index for the home progress UI (last = delivered).
    var stepIndex: Int {
        orderStatusToTrackingStep(status, isCarWash: isCarWash)
    }

    /// Etiqueta para listas con varios pedidos activos.
    var productSummary: String {
        productLines.map { line in
            line.quantity > 1 ? "\(line.name) ×\(line.quantity)" : line.name
        }.joined(separator: ", ")
    }
}

struct OrderHistoryItem: Identifiable, Hashable, Sendable {
    let id: String
    let status: String
    var total: Double
    var createdAt: String?
    var shopName: String?
    var productLines: [ActiveOrderProductLine]

    init(
        id: String,
        status: String,
        total: Double = 0,
        createdAt: String? = nil,
        shopName: String? = nil,
        productLines: [ActiveOrderProductLine] = []
    ) {
        self.id = id
        self.status = status
        self.total = total
        self.createdAt = createdAt
        self.shopName = shopName
        self.productLines = productLines
    }

    var productSummary: String {
        productLines.map { line in
            line.quantity > 1 ? "\(line.name) ×\(line.quantity)" : line.name
        }.joined(separator: ", ")
    }

    var displayTitle: String {
        if let shopName, !shopName.isEmpty { return shopName }
        if !productSummary.isEmpty { return productSummary }
        return "Pedido"
    }
}

func orderStatusToTrackingStep(_ status: String, isCarWash: Bool = false) -> Int {
    if isCarWash {
        switch status.uppercased() {
        case "PENDING": return 0
        case "CONFIRMED": return 1
        case "OUT_FOR_PICKUP": return 2
        case "PICKED_UP": return 3
        case "PREPARING": return 4
        case "READY_FOR_PICKUP": return 5
        case "ASSIGNED": return 6
        case "ON_DELIVERY": return 7
        case "DELIVERED": return 8
        case "CANCELLED": return 0
        default: return 0
        }
    }
    switch status.uppercased() {
    case "PENDING": return 0
    case "CONFIRMED": return 1
    case "PREPARING": return 2
    case "READY_FOR_PICKUP": return 3
    case "ASSIGNED": return 4
    case "ON_DELIVERY": return 5
    case "DELIVERED": return 6
    case "CANCELLED": return 0
    default: return 0
    }
}
