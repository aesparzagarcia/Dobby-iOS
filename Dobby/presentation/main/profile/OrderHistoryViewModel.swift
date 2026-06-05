//
//  OrderHistoryViewModel.swift
//  Dobby
//

import Foundation

struct OrderHistoryUiState: Sendable {
    var orders: [OrderHistoryItem] = []
    var isLoading = false
    var errorMessage: String?
}

@MainActor
@Observable
final class OrderHistoryViewModel {
    private(set) var uiState = OrderHistoryUiState()

    private let orderRepository: OrderRepository

    init(orderRepository: OrderRepository) {
        self.orderRepository = orderRepository
    }

    func load() async {
        uiState.isLoading = true
        uiState.errorMessage = nil
        let result = await orderRepository.getOrderHistory()
        switch result {
        case .success(let orders):
            uiState.orders = orders
            uiState.isLoading = false
        case .failure(let error):
            uiState.isLoading = false
            if error.shouldSuppressUserMessage {
                uiState.errorMessage = nil
            } else {
                uiState.errorMessage = "Error al cargar pedidos"
            }
        }
    }
}
