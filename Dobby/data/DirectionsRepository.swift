//
//  DirectionsRepository.swift
//  Dobby
//
//  Parity with Android `DirectionsRepository` / `DirectionsRepositoryImpl`.
//

import CoreLocation
import Foundation

protocol DirectionsRepository: Sendable {
    func getRoutePoints(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async -> Result<[CLLocationCoordinate2D], DirectionsError>
}

final class DirectionsRepositoryImpl: DirectionsRepository, @unchecked Sendable {
    private let client: GoogleDirectionsClient
    private let apiKey: String

    init(client: GoogleDirectionsClient = GoogleDirectionsClient(), apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }

    func getRoutePoints(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async -> Result<[CLLocationCoordinate2D], DirectionsError> {
        await client.getRoutePoints(origin: origin, destination: destination, apiKey: apiKey)
    }
}
