//
//  OrderPushNavigation.swift
//  Dobby
//

import Foundation

enum OrderPushNavigation {
    private static let terminalStatuses: Set<String> = ["DELIVERED", "CANCELLED"]

    /// Pedidos terminados: no abrir seguimiento desde push, volver a home.
    static func canOpenTracking(status: String) -> Bool {
        !terminalStatuses.contains(status.uppercased())
    }
}
