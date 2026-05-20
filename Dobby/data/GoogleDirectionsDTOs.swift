//
//  GoogleDirectionsDTOs.swift
//  Dobby
//

import Foundation

struct GoogleDirectionsResponse: Decodable, Sendable {
    let status: String?
    let errorMessage: String?
    let routes: [DirectionsRoute]?

    enum CodingKeys: String, CodingKey {
        case status
        case errorMessage = "error_message"
        case routes
    }
}

struct DirectionsRoute: Decodable, Sendable {
    let overviewPolyline: DirectionsPolyline?

    enum CodingKeys: String, CodingKey {
        case overviewPolyline = "overview_polyline"
    }
}

struct DirectionsPolyline: Decodable, Sendable {
    let points: String?
}
