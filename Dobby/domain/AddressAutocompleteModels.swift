//
//  AddressAutocompleteModels.swift
//  Dobby
//
//  Parity with Android `AddressSearchResult`, `NavigateToMapData`, `AddressPrediction`.
//

import Foundation

struct AddressSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
}

struct NavigateToMapData: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let addressLabel: String
    /// When true, map screen uses “My location” title (device GPS), not “Chosen address” (search).
    let isDeviceLocation: Bool

    init(latitude: Double, longitude: Double, addressLabel: String, isDeviceLocation: Bool = false) {
        self.latitude = latitude
        self.longitude = longitude
        self.addressLabel = addressLabel
        self.isDeviceLocation = isDeviceLocation
    }
}

struct AddressPrediction: Sendable {
    let placeId: String
    let mainText: String
    let secondaryText: String?
}
