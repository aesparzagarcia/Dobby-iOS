//
//  PlacesAutocompleteDTOs.swift
//  Dobby
//
//  Google Places API JSON (legacy REST), aligned with Android `PlacesAutocompleteDtos.kt`.
//

import Foundation

struct PlacesAutocompleteResponseDTO: Decodable {
    let predictions: [PlacePredictionDTO]?
    let status: String?
    /// Present when `status` is `REQUEST_DENIED` or other errors; explains the denial in Google’s words.
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case predictions
        case status
        case errorMessage = "error_message"
    }
}

struct PlacePredictionDTO: Decodable {
    let description: String
    let placeId: String
    let structuredFormatting: StructuredFormattingDTO?

    enum CodingKeys: String, CodingKey {
        case description
        case placeId = "place_id"
        case structuredFormatting = "structured_formatting"
    }
}

struct StructuredFormattingDTO: Decodable {
    let mainText: String?
    let secondaryText: String?

    enum CodingKeys: String, CodingKey {
        case mainText = "main_text"
        case secondaryText = "secondary_text"
    }
}

struct PlaceDetailsResponseDTO: Decodable {
    let result: PlaceDetailsResultDTO?
    let status: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case result
        case status
        case errorMessage = "error_message"
    }
}

// MARK: - Geocoding (reverse)

struct GeocodeResponseDTO: Decodable {
    let results: [GeocodeResultDTO]?
    let status: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case results
        case status
        case errorMessage = "error_message"
    }
}

struct GeocodeResultDTO: Decodable {
    let formattedAddress: String?

    enum CodingKeys: String, CodingKey {
        case formattedAddress = "formatted_address"
    }
}

struct PlaceDetailsResultDTO: Decodable {
    let geometry: PlaceGeometryDTO?
}

struct PlaceGeometryDTO: Decodable {
    let location: PlaceLocationDTO?
}

struct PlaceLocationDTO: Decodable {
    let lat: Double
    let lng: Double
}
