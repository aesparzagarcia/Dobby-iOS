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
    var productLines: [ActiveOrderProductLine]

    init(
        id: String,
        status: String,
        total: Double = 0,
        deliveryAddress: String? = nil,
        createdAt: String? = nil,
        productLines: [ActiveOrderProductLine] = []
    ) {
        self.id = id
        self.status = status
        self.total = total
        self.deliveryAddress = deliveryAddress
        self.createdAt = createdAt
        self.productLines = productLines
    }

    /// Step index 0…6 for the 7-stage progress UI (6 = delivered).
    var stepIndex: Int {
        orderStatusToTrackingStep(status)
    }

    /// Etiqueta para listas con varios pedidos activos.
    var productSummary: String {
        productLines.map { line in
            line.quantity > 1 ? "\(line.name) ×\(line.quantity)" : line.name
        }.joined(separator: ", ")
    }
}

func orderStatusToTrackingStep(_ status: String) -> Int {
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
