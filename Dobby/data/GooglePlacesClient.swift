//
//  GooglePlacesClient.swift
//  Dobby
//
//  GET `https://maps.googleapis.com/maps/api/...` (same as Android `NetworkModule` Google Retrofit).
//

import Foundation
import os.log

enum PlacesAutocompleteError: Error, Sendable {
    case missingApiKey
    case apiStatus(String)
    case noGeometry
    case invalidURL
    case transport(Error)
    case decoding(Error)
}

struct GooglePlacesClient: Sendable {
    private static let log = Logger(subsystem: "com.ares.Dobby", category: "GooglePlaces")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getAddressPredictions(input: String, apiKey: String) async -> Result<[AddressPrediction], PlacesAutocompleteError> {
        guard !apiKey.isEmpty else { return .failure(.missingApiKey) }
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")!
        components.queryItems = [
            URLQueryItem(name: "input", value: input),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "types", value: "address"),
            URLQueryItem(name: "language", value: "en"),
        ]
        guard let url = components.url else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        Self.log.info("Places autocomplete request")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.transport(URLError(.badServerResponse)))
            }
            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.apiStatus("HTTP \(http.statusCode)"))
            }
            let decoded: PlacesAutocompleteResponseDTO
            do {
                decoded = try JSONDecoder().decode(PlacesAutocompleteResponseDTO.self, from: data)
            } catch {
                return .failure(.decoding(error))
            }
            let status = decoded.status ?? ""
            if status != "OK", status != "ZERO_RESULTS" {
                let detail = [status as String?, decoded.errorMessage]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ": ")
                return .failure(.apiStatus(detail))
            }
            let list = (decoded.predictions ?? []).map { p in
                AddressPrediction(
                    placeId: p.placeId,
                    mainText: p.structuredFormatting?.mainText ?? p.description,
                    secondaryText: p.structuredFormatting?.secondaryText
                )
            }
            return .success(list)
        } catch {
            return .failure(.transport(error))
        }
    }

    func getPlaceLocation(placeId: String, apiKey: String) async -> Result<(Double, Double), PlacesAutocompleteError> {
        guard !apiKey.isEmpty else { return .failure(.missingApiKey) }
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "fields", value: "geometry"),
        ]
        guard let url = components.url else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return .failure(.transport(URLError(.badServerResponse)))
            }
            let decoded: PlaceDetailsResponseDTO
            do {
                decoded = try JSONDecoder().decode(PlaceDetailsResponseDTO.self, from: data)
            } catch {
                return .failure(.decoding(error))
            }
            guard decoded.status == "OK", let loc = decoded.result?.geometry?.location else {
                let s = decoded.status ?? "UNKNOWN"
                let detail = [s as String?, decoded.errorMessage]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ": ")
                return .failure(.apiStatus(detail))
            }
            return .success((loc.lat, loc.lng))
        } catch {
            return .failure(.transport(error))
        }
    }

    /// Reverse geocode (parity with Android `GooglePlacesApi.getReverseGeocode` / Geocoding API).
    func getAddressFromLocation(latitude: Double, longitude: Double, apiKey: String) async -> Result<String, PlacesAutocompleteError> {
        guard !apiKey.isEmpty else { return .failure(.missingApiKey) }
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
        components.queryItems = [
            URLQueryItem(name: "latlng", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "language", value: "en"),
        ]
        guard let url = components.url else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return .failure(.transport(URLError(.badServerResponse)))
            }
            let decoded: GeocodeResponseDTO
            do {
                decoded = try JSONDecoder().decode(GeocodeResponseDTO.self, from: data)
            } catch {
                return .failure(.decoding(error))
            }
            guard decoded.status == "OK", let formatted = decoded.results?.first?.formattedAddress, !formatted.isEmpty else {
                let s = decoded.status ?? "UNKNOWN"
                let detail = [s as String?, decoded.errorMessage]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ": ")
                return .failure(.apiStatus(detail.isEmpty ? "No address found" : detail))
            }
            return .success(formatted)
        } catch {
            return .failure(.transport(error))
        }
    }
}
