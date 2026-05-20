//
//  GoogleDirectionsClient.swift
//  Dobby
//
//  GET `https://maps.googleapis.com/maps/api/directions/json` (parity with Android `GoogleDirectionsApi`).
//

import CoreLocation
import Foundation
import os.log

enum DirectionsError: Error, Sendable {
    case missingApiKey
    case apiStatus(String, String?)
    case invalidURL
    case transport(Error)
    case decoding(Error)
}

struct GoogleDirectionsClient: Sendable {
    private static let log = Logger(subsystem: "com.ares.Dobby", category: "Directions")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getRoutePoints(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        apiKey: String
    ) async -> Result<[CLLocationCoordinate2D], DirectionsError> {
        guard !apiKey.isEmpty else { return .failure(.missingApiKey) }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "key", value: apiKey),
        ]
        guard let url = components.url else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.apiStatus("HTTP", nil))
            }
            let body: GoogleDirectionsResponse
            do {
                body = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: data)
            } catch {
                Self.log.error("Directions decode failed: \(error.localizedDescription)")
                return .failure(.decoding(error))
            }

            guard http.statusCode == 200 else {
                let status = body.status ?? "HTTP \(http.statusCode)"
                let msg = body.errorMessage
                Self.log.error("Directions API failed: status=\(status), message=\(msg ?? "")")
                return .failure(.apiStatus(status, msg))
            }

            guard body.status == "OK" else {
                let status = body.status ?? "UNKNOWN"
                let msg = body.errorMessage ?? "Directions API: \(status)"
                Self.log.error("Directions API status not OK: \(status), \(msg)")
                if status == "REQUEST_DENIED" {
                    Self.log.error(
                        "REQUEST_DENIED: enable Directions API + billing; use DIRECTIONS_API_KEY without iOS/Android-only restriction."
                    )
                }
                return .failure(.apiStatus(status, msg))
            }

            let encoded = body.routes?.first?.overviewPolyline?.points
            let points = encoded.map { PolylineDecoder.decode($0) } ?? []
            Self.log.debug("Route decoded: \(points.count) points")
            return .success(points)
        } catch {
            Self.log.error("Directions request failed: \(error.localizedDescription)")
            return .failure(.transport(error))
        }
    }
}
