//
//  AuthSessionNavigation.swift
//  Dobby
//
//  When auth fails fatally (invalid refresh), return the guest Home.
//  Parallel 401s and cancelled in-flight requests must not remount Home in a loop.
//

import Foundation

enum AuthSessionNavigation {
    private static let lock = NSLock()
    private static var expiredGate = false

    static func notifySessionExpired() {
        lock.lock()
        let shouldPost = !expiredGate
        if shouldPost { expiredGate = true }
        lock.unlock()
        guard shouldPost else { return }
        NotificationCenter.default.post(name: .dobbySessionExpired, object: nil)
    }

    /// After a successful login / registration so a later 401 can navigate again.
    static func resetExpiredGate() {
        lock.lock()
        expiredGate = false
        lock.unlock()
    }

    /// Call when an authenticated API call returns a fatal 401. Guest browse and
    /// cancelled tasks (leaving Home to open login) must not fire this.
    static func notifyIfUnauthorized(_ error: HTTPClientError, sessionStore: SessionStore) {
        guard sessionStore.isLoggedIn else { return }
        switch error {
        case .statusCode(401, _):
            notifySessionExpired()
        default:
            break
        }
    }

    /// Call when `accessToken` is missing for an endpoint that requires auth.
    /// Guest browse is allowed: do not force navigation — callers should prompt login locally.
    static func notifyIfMissingAccessToken() {}

    static func shouldSuppressUserMessage(for error: HTTPClientError) -> Bool {
        error.shouldSuppressUserFacingMessage
    }
}
