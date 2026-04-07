//
//  AuthRepositoryImpl.swift
//  Dobby
//

import Foundation

final class AuthRepositoryImpl: AuthRepository, @unchecked Sendable {
    private let api: DobbyHTTPClient
    private let sessionStore: SessionStore
    private let tokenRefresh: ConsumerTokenRefreshService

    init(api: DobbyHTTPClient, sessionStore: SessionStore, tokenRefresh: ConsumerTokenRefreshService) {
        self.api = api
        self.sessionStore = sessionStore
        self.tokenRefresh = tokenRefresh
    }

    var isLoggedIn: Bool { sessionStore.isLoggedIn }

    func requestOtp(phone: String) async -> AuthResult<OtpRequestResult> {
        let result: Result<RequestOtpResponseDTO, HTTPClientError> = await api.post(
            "auth/request-otp",
            body: RequestOtpRequestDTO(phone: phone)
        )
        switch result {
        case .success(let r):
            return .success(OtpRequestResult(userExists: r.userExists))
        case .failure(let e):
            return .error(api.userFacingMessage(from: e))
        }
    }

    func verifyOtp(phone: String, code: String) async -> AuthResult<VerifyOtpOutcome> {
        let result: Result<VerifyOtpResponseDTO, HTTPClientError> = await api.post(
            "auth/verify-otp",
            body: VerifyOtpRequestDTO(phone: phone, code: code)
        )
        switch result {
        case .success(let r):
            if r.requiresRegistration {
                return .success(.requiresRegistration)
            }
            guard let access = r.token, let refresh = r.refreshToken, !access.isEmpty, !refresh.isEmpty else {
                return .error("Respuesta de sesión inválida")
            }
            sessionStore.saveSession(accessToken: access, refreshToken: refresh, userId: r.user?.id)
            return .success(.loggedIn)
        case .failure(let e):
            return .error(api.userFacingMessage(from: e))
        }
    }

    func completeRegistration(phone: String, name: String, lastName: String, email: String) async -> AuthResult<Void> {
        let result: Result<CompleteRegistrationResponseDTO, HTTPClientError> = await api.post(
            "auth/complete-registration",
            body: CompleteRegistrationRequestDTO(phone: phone, name: name, lastName: lastName, email: email)
        )
        switch result {
        case .success(let r):
            guard let refresh = r.refreshToken, !refresh.isEmpty else {
                return .error("Respuesta de sesión inválida")
            }
            sessionStore.saveSession(accessToken: r.token, refreshToken: refresh, userId: r.user?.id)
            return .success(())
        case .failure(let e):
            return .error(api.userFacingMessage(from: e))
        }
    }

    func logout() async {
        sessionStore.clearSession()
    }

    func syncSessionAtLaunch() async -> Bool {
        if !isLoggedIn { return false }
        switch await tokenRefresh.refreshStoredSession() {
        case .sessionDead:
            return false
        case .skipped, .refreshed, .unchanged:
            return true
        }
    }
}
