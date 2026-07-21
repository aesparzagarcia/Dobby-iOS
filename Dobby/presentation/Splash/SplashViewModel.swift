//
//  SplashViewModel.swift
//  Dobby
//

import Foundation

@MainActor
@Observable
final class SplashViewModel {
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
    }

    /// Always opens Home (guest browse). Syncs session when already logged in.
    func resolveSplashDestination() async -> Bool {
        if deps.authRepository.isLoggedIn {
            _ = await deps.authRepository.syncSessionAtLaunch()
        }
        let snapshot = await HomeBootstrapLoader.load(deps: deps)
        HomeBootstrapCache.shared.store(snapshot)
        return true
    }
}
