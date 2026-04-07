//
//  RootView.swift
//  Dobby
//

import SwiftData
import SwiftUI

struct RootView: View {
    let deps: AppDependencies

    @State private var route: AppRoute = .splash

    var body: some View {
        Group {
            switch route {
            case .splash:
                SplashView(viewModel: SplashViewModel(authRepository: deps.authRepository)) { openHome in
                    route = openHome ? .home : .phone
                }
            case .phone:
                PhoneScreen(
                    viewModel: PhoneViewModel(authRepository: deps.authRepository),
                    onCodeSent: { phone, userExists in
                        route = .otp(phone: phone, userExists: userExists)
                    },
                    onBack: nil
                )
            case .otp(let phone, _):
                OtpScreen(
                    viewModel: OtpViewModel(authRepository: deps.authRepository, phone: phone),
                    onLoggedIn: { route = .home },
                    onRequiresRegistration: { route = .register(phone: $0) },
                    onBack: { route = .phone }
                )
            case .register(let phone):
                RegisterUserScreen(
                    viewModel: RegisterUserViewModel(authRepository: deps.authRepository, phone: phone),
                    onComplete: { route = .home },
                    onBack: { route = .otp(phone: phone, userExists: true) }
                )
            case .home:
                MainTabView(deps: deps) {
                    Task {
                        await deps.authRepository.logout()
                        await MainActor.run { route = .phone }
                    }
                }
            }
        }
        .modelContainer(CartSwiftDataStack.sharedContainer)
        .onReceive(NotificationCenter.default.publisher(for: .dobbySessionExpired)) { _ in
            if case .home = route {
                route = .phone
            }
        }
    }
}
