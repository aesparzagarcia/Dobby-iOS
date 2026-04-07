//
//  DeviceLocationFetcher.swift
//  Dobby
//
//  One-shot GPS read for “My current location” (parity with Android `FusedLocationProvider`).
//

import CoreLocation
import Foundation

enum DeviceLocationFetchError: LocalizedError {
    case denied
    case noLocation

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Permite el acceso a la ubicación en Ajustes para usar tu posición actual."
        case .noLocation:
            return "No se pudo obtener tu ubicación. Comprueba que los servicios de ubicación estén activados."
        }
    }
}

/// Requests a single fix; create a **new** instance per request.
@MainActor
final class OneShotLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func getLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            continuation = cont
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                cont.resume(throwing: DeviceLocationFetchError.denied)
                continuation = nil
            @unknown default:
                cont.resume(throwing: DeviceLocationFetchError.noLocation)
                continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if continuation != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            continuation?.resume(throwing: DeviceLocationFetchError.denied)
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        continuation?.resume(returning: loc)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let c = continuation {
            c.resume(throwing: error)
            continuation = nil
        }
    }
}
