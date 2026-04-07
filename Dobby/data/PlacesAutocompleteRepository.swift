//
//  PlacesAutocompleteRepository.swift
//  Dobby
//
//  Parity with Android `PlacesAutocompleteRepository` / `PlacesAutocompleteRepositoryImpl`.
//

import Foundation

protocol PlacesAutocompleteRepository: Sendable {
    func getAddressPredictions(input: String) async -> Result<[AddressPrediction], PlacesAutocompleteError>
    func getPlaceLocation(placeId: String) async -> Result<(Double, Double), PlacesAutocompleteError>
    func getAddressFromLocation(latitude: Double, longitude: Double) async -> Result<String, PlacesAutocompleteError>
}

final class PlacesAutocompleteRepositoryImpl: PlacesAutocompleteRepository, @unchecked Sendable {
    private let client: GooglePlacesClient
    private let apiKey: String

    init(client: GooglePlacesClient = GooglePlacesClient(), apiKey: String) {
        self.client = client
        self.apiKey = apiKey
    }

    func getAddressPredictions(input: String) async -> Result<[AddressPrediction], PlacesAutocompleteError> {
        await client.getAddressPredictions(input: input, apiKey: apiKey)
    }

    func getPlaceLocation(placeId: String) async -> Result<(Double, Double), PlacesAutocompleteError> {
        await client.getPlaceLocation(placeId: placeId, apiKey: apiKey)
    }

    func getAddressFromLocation(latitude: Double, longitude: Double) async -> Result<String, PlacesAutocompleteError> {
        await client.getAddressFromLocation(latitude: latitude, longitude: longitude, apiKey: apiKey)
    }
}
