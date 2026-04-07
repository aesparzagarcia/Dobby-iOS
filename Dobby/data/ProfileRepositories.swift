//
//  ProfileRepositories.swift
//  Dobby
//
//  Parity with Android `ProfileRepository` / `ProfileRepositoryImpl`.
//

import Foundation

enum ProfileRepositoryError: Error, Sendable {
    case notAuthenticated
    case http(HTTPClientError)

    var shouldSuppressUserMessage: Bool {
        switch self {
        case .notAuthenticated:
            return true
        case .http(let e):
            return AuthSessionNavigation.shouldSuppressUserMessage(for: e)
        }
    }
}

protocol ProfileRepository: Sendable {
    func getGamification() async -> Result<GamificationDto, ProfileRepositoryError>
}

final class ProfileRepositoryImpl: ProfileRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore

    init(api: DobbyHTTPClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func getGamification() async -> Result<GamificationDto, ProfileRepositoryError> {
        guard let token = sessionStore.accessToken() else {
            AuthSessionNavigation.notifyIfMissingAccessToken()
            return .failure(.notAuthenticated)
        }
        let result: Result<GamificationDto, HTTPClientError> = await api.get("app/me/gamification", bearerToken: token)
        switch result {
        case .success(let dto):
            return .success(dto)
        case .failure(let e):
            AuthSessionNavigation.notifyIfUnauthorized(e, sessionStore: sessionStore)
            return .failure(.http(e))
        }
    }
}
