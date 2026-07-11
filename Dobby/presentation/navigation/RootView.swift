//
//  RootView.swift
//  Dobby
//

import SwiftData
import SwiftUI

struct RootView: View {
    let deps: AppDependencies

    @Environment(\.scenePhase) private var scenePhase
    @State private var route: AppRoute = .splash
    @State private var phoneViewModel: PhoneViewModel
    @State private var otpViewModel: OtpViewModel?

    init(deps: AppDependencies) {
        self.deps = deps
        _phoneViewModel = State(wrappedValue: PhoneViewModel(authRepository: deps.authRepository))
    }

    var body: some View {
        Group {
            switch route {
            case .splash:
                SplashView(viewModel: SplashViewModel(deps: deps)) { openHome in
                    route = openHome ? .home : .phone
                }
            case .phone:
                PhoneScreen(
                    viewModel: phoneViewModel,
                    onCodeSent: { phone, userExists in
                        otpViewModel = OtpViewModel(authRepository: deps.authRepository, phone: phone)
                        route = .otp(phone: phone, userExists: userExists)
                    },
                    onBack: nil
                )
            case .otp(_, _):
                if let otpViewModel {
                    OtpScreen(
                        viewModel: otpViewModel,
                        onLoggedIn: {
                            self.otpViewModel = nil
                            route = .home
                        },
                        onRequiresRegistration: { route = .register(phone: $0) },
                        onBack: {
                            self.otpViewModel = nil
                            route = .phone
                        }
                    )
                }
            case .register(let phone):
                RegisterUserScreen(
                    viewModel: RegisterUserViewModel(authRepository: deps.authRepository, phone: phone),
                    onComplete: { route = .home },
                    onBack: { route = .phone }
                )
            case .home:
                MainTabView(deps: deps) {
                    Task {
                        await deps.authRepository.logout()
                        await MainActor.run {
                            phoneViewModel = PhoneViewModel(authRepository: deps.authRepository)
                            otpViewModel = nil
                            route = .phone
                        }
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await deps.tokenRefresh.refreshAccessTokenOnForeground()
                    await DobbyPushSync.sync(api: deps.httpClient, sessionStore: deps.sessionStore)
                }
            }
        }
        .modelContainer(CartSwiftDataStack.sharedContainer)
        .onReceive(NotificationCenter.default.publisher(for: .dobbySessionExpired)) { _ in
            if case .home = route {
                phoneViewModel = PhoneViewModel(authRepository: deps.authRepository)
                otpViewModel = nil
                route = .phone
            }
        }
    }
}
