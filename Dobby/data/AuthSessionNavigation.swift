//
//  AuthSessionNavigation.swift
//  Dobby
//
//  When auth fails fatally (401/403, missing token, cancelled after session cleared), navigate to login
//  without showing an error sheet or “Reintentar” / dismiss UI.
//

import Foundation

enum AuthSessionNavigation {
    static func notifySessionExpired() {
        NotificationCenter.default.post(name: .dobbySessionExpired, object: nil)
    }

    /// Call when an authenticated API call returns an HTTP failure.
    static func notifyIfUnauthorized(_ error: HTTPClientError, sessionStore: SessionStore) {
        switch error {
        case .statusCode(401, _), .statusCode(403, _):
            notifySessionExpired()
        case .transport(let e):
            if let url = e as? URLError, url.code == .cancelled, !sessionStore.isLoggedIn {
                notifySessionExpired()
            }
        default:
            break
        }
    }

    /// Call when `accessToken` is missing for an endpoint that requires auth.
    static func notifyIfMissingAccessToken() {
        notifySessionExpired()
    }

    static func shouldSuppressUserMessage(for error: HTTPClientError) -> Bool {
        switch error {
        case .statusCode(401, _), .statusCode(403, _):
            return true
        case .transport(let e):
            if let url = e as? URLError, url.code == .cancelled {
                return true
            }
            return false
        default:
            return false
        }
    }
}
