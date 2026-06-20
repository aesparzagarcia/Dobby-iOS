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

    func resolveSplashDestination() async -> Bool {
        guard deps.authRepository.isLoggedIn else {
            return false
        }
        guard await deps.authRepository.syncSessionAtLaunch() else {
            return false
        }

        let snapshot = await HomeBootstrapLoader.load(deps: deps)
        HomeBootstrapCache.shared.store(snapshot)
        return true
    }
}
