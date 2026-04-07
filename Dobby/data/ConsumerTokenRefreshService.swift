//
//  ConsumerTokenRefreshService.swift
//  Dobby
//
//  Parity with Android `ConsumerTokenRefreshService` + mutex coordination on 401.
//

import Foundation

enum ConsumerLaunchRefreshOutcome: Sendable {
    case skipped
    case refreshed
    case unchanged
    case sessionDead
}

/// Parity with Android `ConsumerCoordinatorResult`.
enum ConsumerCoordinatorResult: Sendable {
    case noRefreshStored
    case sessionInvalid
    case transientFailure
    case useAccess(String)
    case newTokens(String)
}

private enum HttpRefreshResult: Sendable {
    case success(String, String)
    case sessionInvalid
    case transientFailure
}

/// Serializes refresh + `coordinateAfter401` (parity with Android `Mutex`).
private actor ConsumerRefreshCoordinator {
    private let http: DobbyHTTPClient

    init(http: DobbyHTTPClient) {
        self.http = http
    }

    func coordinateAfter401(requestAccessToken: String, sessionStore: SessionStore) async -> ConsumerCoordinatorResult {
        let trimmedRequest = requestAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentAccess = sessionStore.accessToken() ?? ""
        if !currentAccess.isEmpty && currentAccess != trimmedRequest {
            return .useAccess(currentAccess)
        }
        guard let refresh = sessionStore.refreshTokenValue(), !refresh.isEmpty else {
            return .noRefreshStored
        }
        switch await executeRefresh(refresh: refresh) {
        case .success(let access, let next):
            sessionStore.saveSession(accessToken: access, refreshToken: next, userId: nil)
            return .newTokens(access)
        case .sessionInvalid:
            return .sessionInvalid
        case .transientFailure:
            return .transientFailure
        }
    }

    func refreshStoredSession(sessionStore: SessionStore) async -> ConsumerLaunchRefreshOutcome {
        guard let refresh = sessionStore.refreshTokenValue(), !refresh.isEmpty else {
            return .skipped
        }
        switch await executeRefresh(refresh: refresh) {
        case .success(let access, let next):
            sessionStore.saveSession(accessToken: access, refreshToken: next, userId: nil)
            return .refreshed
        case .sessionInvalid:
            sessionStore.clearSession()
            return .sessionDead
        case .transientFailure:
            return .unchanged
        }
    }

    /// Uses plain `DobbyHTTPClient` (no 401 retry) — parity with Android `@DobbyNoAuthClient`.
    private func executeRefresh(refresh: String) async -> HttpRefreshResult {
        let result: Result<AppRefreshResponseDTO, HTTPClientError> = await http.post(
            "auth/refresh",
            body: AppRefreshRequestDTO(refreshToken: refresh)
        )
        switch result {
        case .success(let resp):
            guard let access = resp.token, let next = resp.refreshToken, !access.isEmpty, !next.isEmpty else {
                return .transientFailure
            }
            return .success(access, next)
        case .failure(let err):
            switch err {
            case .statusCode(let code, _) where code == 401 || code == 403:
                return .sessionInvalid
            case .statusCode(let code, _) where code == 400:
                return .sessionInvalid
            case .statusCode(let code, _) where (500 ... 599).contains(code):
                return .transientFailure
            case .statusCode:
                return .transientFailure
            case .transport:
                return .transientFailure
            case .invalidURL, .decoding:
                return .transientFailure
            }
        }
    }
}

/// Parity with Android `ConsumerTokenRefreshService`.
final class ConsumerTokenRefreshService: @unchecked Sendable {
    private let http: DobbyHTTPClient
    private let sessionStore: SessionStore
    private let coordinator: ConsumerRefreshCoordinator

    init(http: DobbyHTTPClient, sessionStore: SessionStore) {
        self.http = http
        self.sessionStore = sessionStore
        self.coordinator = ConsumerRefreshCoordinator(http: http)
    }

    func coordinateAfter401(requestAccessToken: String) async -> ConsumerCoordinatorResult {
        await coordinator.coordinateAfter401(requestAccessToken: requestAccessToken, sessionStore: sessionStore)
    }

    func refreshStoredSession() async -> ConsumerLaunchRefreshOutcome {
        await coordinator.refreshStoredSession(sessionStore: sessionStore)
    }

    /// While app is active: refresh if access JWT expires within [threshold] seconds (parity with Android `ProactiveAccessTokenRefresh`).
    func refreshIfAccessTokenExpiringSoon(
        thresholdSeconds: Int64 = 10 * 60,
        now: () -> Int64 = { Int64(Date().timeIntervalSince1970) }
    ) async {
        guard sessionStore.isLoggedIn else { return }
        guard let access = sessionStore.accessToken(), !access.isEmpty else { return }
        guard let exp = AccessTokenJwtParser.expiryEpochSeconds(access) else { return }
        let secondsLeft = exp - now()
        if secondsLeft > thresholdSeconds { return }
        guard sessionStore.refreshTokenValue() != nil else { return }
        let outcome = await refreshStoredSession()
        if case .sessionDead = outcome {
            NotificationCenter.default.post(name: .dobbySessionExpired, object: nil)
        }
    }
}
