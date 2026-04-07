//
//  SplashViewModel.swift
//  Dobby
//

import Foundation

@MainActor
@Observable
final class SplashViewModel {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func shouldOpenHomeAfterSplash() async -> Bool {
        if !authRepository.isLoggedIn { return false }
        return await authRepository.syncSessionAtLaunch()
    }
}
