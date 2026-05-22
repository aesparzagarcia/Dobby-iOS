//
//  OrderTrackingViewModel.swift
//  Dobby
//
//  Parity with Android `OrderTrackingViewModel` (load + poll + Google Directions route).
//

import CoreLocation
import Foundation

private let locationPollIntervalNs: UInt64 = 3_000_000_000
/// Avoid Directions API burst while courier position updates (Android: 20s).
private let routeMinIntervalNs: UInt64 = 20_000_000_000

@MainActor
@Observable
final class OrderTrackingViewModel {
    private let orderRepository: OrderRepository
    private let directionsRepository: DirectionsRepository
    private let http: DobbyHTTPClient
    let orderId: String

    var tracking: OrderTrackingDetail?
    var isLoading = true
    var errorMessage: String?
    var rateSubmitting = false
    var rateError: String?

    /// Driving route repartidor → delivery (Google Directions), or straight segment if API fails.
    var routePoints: [CLLocationCoordinate2D] = []
    /// True when Directions did not return a street polyline.
    var usingStraightLineRoute = false

    private var pollTask: Task<Void, Never>?
    private var lastDmLat: Double?
    private var lastDmLng: Double?
    private var lastRouteFetchAt: UInt64 = 0
    private var lastRouteStatus: String?

    init(
        orderId: String,
        orderRepository: OrderRepository,
        directionsRepository: DirectionsRepository,
        http: DobbyHTTPClient
    ) {
        self.orderId = orderId
        self.orderRepository = orderRepository
        self.directionsRepository = directionsRepository
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
                try? await Task.sleep(nanoseconds: locationPollIntervalNs)
                let status = self.tracking?.status.uppercased() ?? ""
                guard status == "ASSIGNED" || status == "ON_DELIVERY" else { continue }
                switch await self.orderRepository.getOrderTracking(orderId: self.orderId) {
                case .success(let t):
                    if let t { self.onTrackingRefreshed(t) }
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
            // Keep the Map mounted during refresh — toggling `isLoading` removed the Map and
            // triggered Metal "drawable destroyed while command buffer alive" crashes.
            let isInitialLoad = tracking == nil
            if isInitialLoad {
                isLoading = true
                errorMessage = nil
            }
            switch await orderRepository.getOrderTracking(orderId: orderId) {
            case .success(let t):
                isLoading = false
                if let t {
                    tracking = t
                    errorMessage = nil
                    onTrackingRefreshed(t)
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

    private func onTrackingRefreshed(_ tracking: OrderTrackingDetail) {
        let dm = tracking.deliveryMan
        let lat = dm?.lat
        let lng = dm?.lng
        if lat == nil || lng == nil {
            lastDmLat = nil
            lastDmLng = nil
            self.tracking = tracking
            maybeRefreshRoute(tracking)
            return
        }
        let moved = lastDmLat == nil || lastDmLng == nil
            || abs(lat! - lastDmLat!) > 1e-5 || abs(lng! - lastDmLng!) > 1e-5
        if moved {
            lastDmLat = lat
            lastDmLng = lng
            self.tracking = tracking
            maybeRefreshRoute(tracking)
            return
        }
        self.tracking = tracking
        maybeRefreshRoute(tracking)
    }

    private func maybeRefreshRoute(_ tracking: OrderTrackingDetail) {
        let statusKey = tracking.status.uppercased()
        if lastRouteStatus != statusKey {
            lastRouteStatus = statusKey
            lastRouteFetchAt = 0
            if !routePoints.isEmpty {
                routePoints = []
                usingStraightLineRoute = false
            }
        }
        guard let routeDest = tracking.routeDestinationCoordinate,
              let dm = tracking.deliveryMan,
              let oLat = dm.lat, let oLng = dm.lng
        else {
            if !routePoints.isEmpty {
                routePoints = []
                usingStraightLineRoute = false
            }
            return
        }

        let origin = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
        let destination = CLLocationCoordinate2D(latitude: routeDest.lat, longitude: routeDest.lng)
        let now = DispatchTime.now().uptimeNanoseconds
        if !routePoints.isEmpty, now &- lastRouteFetchAt < routeMinIntervalNs { return }
        lastRouteFetchAt = now

        Task {
            switch await directionsRepository.getRoutePoints(origin: origin, destination: destination) {
            case .success(let points):
                if points.isEmpty {
                    routePoints = [origin, destination]
                    usingStraightLineRoute = true
                } else {
                    routePoints = points
                    usingStraightLineRoute = false
                }
            case .failure:
                routePoints = [origin, destination]
                usingStraightLineRoute = true
            }
        }
    }

    func submitDeliveryRating(_ stars: Int) {
        submitRating(stars: stars) { await self.orderRepository.rateDelivery(orderId: self.orderId, stars: stars) }
    }

    func submitShopRating(_ stars: Int) {
        submitRating(stars: stars) { await self.orderRepository.rateShop(orderId: self.orderId, stars: stars) }
    }

    func submitProductRating(productId: String, stars: Int) {
        submitRating(stars: stars) {
            await self.orderRepository.rateProduct(orderId: self.orderId, productId: productId, stars: stars)
        }
    }

    private func submitRating(stars: Int, action: @escaping () async -> Result<Void, OrderRepositoryError>) {
        guard stars >= 1, stars <= 5, !orderId.isEmpty else { return }
        Task {
            rateSubmitting = true
            rateError = nil
            switch await action() {
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

    private func message(for error: OrderRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let he):
            return http.userFacingMessage(from: he)
        }
    }
}
