//
//  OrderTrackingViewModel.swift
//  Dobby
//
//  Parity with Android `OrderTrackingViewModel` (load + poll while assigned / en route).
//

import Foundation
import MapKit

@MainActor
@Observable
final class OrderTrackingViewModel {
    private let orderRepository: OrderRepository
    private let http: DobbyHTTPClient
    let orderId: String

    var tracking: OrderTrackingDetail?
    var isLoading = true
    var errorMessage: String?
    var rateSubmitting = false
    var rateError: String?

    private var pollTask: Task<Void, Never>?

    init(orderId: String, orderRepository: OrderRepository, http: DobbyHTTPClient) {
        self.orderId = orderId
        self.orderRepository = orderRepository
        self.http = http
    }

    func onAppear() {
        loadTracking()
        startPollingIfNeeded()
    }

    func onDisappear() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let status = self.tracking?.status.uppercased() ?? ""
                guard status == "ASSIGNED" || status == "ON_DELIVERY" else { continue }
                switch await self.orderRepository.getOrderTracking(orderId: self.orderId) {
                case .success(let t):
                    if let t { self.tracking = t }
                case .failure:
                    break
                }
            }
        }
    }

    func loadTracking() {
        guard !orderId.isEmpty else {
            isLoading = false
            errorMessage = "Falta el identificador del pedido."
            return
        }
        Task {
            isLoading = true
            errorMessage = nil
            switch await orderRepository.getOrderTracking(orderId: orderId) {
            case .success(let t):
                isLoading = false
                if let t {
                    tracking = t
                    errorMessage = nil
                } else {
                    tracking = nil
                    errorMessage = "No encontrado: el pedido no existe o no tienes acceso."
                }
            case .failure(let e):
                isLoading = false
                tracking = nil
                if !e.shouldSuppressUserMessage {
                    errorMessage = message(for: e)
                }
            }
        }
    }

    func submitDeliveryRating(_ stars: Int) {
        guard stars >= 1, stars <= 5, !orderId.isEmpty else { return }
        Task {
            rateSubmitting = true
            rateError = nil
            switch await orderRepository.rateDelivery(orderId: orderId, stars: stars) {
            case .success:
                rateSubmitting = false
                loadTracking()
            case .failure(let e):
                rateSubmitting = false
                if !e.shouldSuppressUserMessage {
                    rateError = message(for: e)
                }
            }
        }
    }

    func clearRateError() {
        rateError = nil
    }

    /// Straight segment courier → delivery (parity with Android when Directions is unavailable).
    var routeCoordinates: [CLLocationCoordinate2D] {
        guard let t = tracking,
              let dLat = t.lat, let dLng = t.lng,
              let dm = t.deliveryMan,
              let oLat = dm.lat, let oLng = dm.lng
        else { return [] }
        return [
            CLLocationCoordinate2D(latitude: oLat, longitude: oLng),
            CLLocationCoordinate2D(latitude: dLat, longitude: dLng),
        ]
    }

    private func message(for error: OrderRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let he):
            return http.userFacingMessage(from: he)
        }
    }
}
