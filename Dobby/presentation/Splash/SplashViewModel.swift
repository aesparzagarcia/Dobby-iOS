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
        async let minDuration: Void = {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }()

        guard deps.authRepository.isLoggedIn else {
            await minDuration
            return false
        }
        guard await deps.authRepository.syncSessionAtLaunch() else {
            await minDuration
            return false
        }

        let snapshot = await HomeBootstrapLoader.load(deps: deps)
        HomeBootstrapCache.shared.store(snapshot)
        await minDuration
        return true
    }
}
