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
    @State private var registerViewModel: RegisterUserViewModel?
    /// Bumps to remount `MainTabView` after login / logout / session expiry.
    @State private var homeEpoch = 0

    init(deps: AppDependencies) {
        self.deps = deps
        _phoneViewModel = State(wrappedValue: PhoneViewModel(authRepository: deps.authRepository))
    }

    var body: some View {
        Group {
            switch route {
            case .splash:
                SplashView(viewModel: SplashViewModel(deps: deps)) { _ in
                    route = .home
                }
            case .phone:
                PhoneScreen(
                    viewModel: phoneViewModel,
                    onCodeSent: { phone, userExists in
                        otpViewModel = OtpViewModel(authRepository: deps.authRepository, phone: phone)
                        route = .otp(phone: phone, userExists: userExists)
                    },
                    onBack: { route = .home }
                )
            case .otp(_, _):
                if let otpViewModel {
                    OtpScreen(
                        viewModel: otpViewModel,
                        onLoggedIn: {
                            self.otpViewModel = nil
                            self.registerViewModel = nil
                            homeEpoch += 1
                            route = .home
                        },
                        onRequiresRegistration: { phone in
                            registerViewModel = RegisterUserViewModel(
                                authRepository: deps.authRepository,
                                phone: phone
                            )
                            route = .register(phone: phone)
                        },
                        onBack: {
                            self.otpViewModel = nil
                            route = .phone
                        }
                    )
                }
            case .register(_):
                if let registerViewModel {
                    RegisterUserScreen(
                        viewModel: registerViewModel,
                        onComplete: {
                            self.otpViewModel = nil
                            self.registerViewModel = nil
                            homeEpoch += 1
                            route = .home
                        },
                        onBack: {
                            self.registerViewModel = nil
                            route = .phone
                        }
                    )
                }
            case .home:
                MainTabView(
                    deps: deps,
                    onLogout: {
                        Task {
                            if deps.authRepository.isLoggedIn {
                                await deps.authRepository.logout()
                            }
                            await MainActor.run {
                                phoneViewModel = PhoneViewModel(authRepository: deps.authRepository)
                                otpViewModel = nil
                                registerViewModel = nil
                                homeEpoch += 1
                                route = .home
                            }
                        }
                    },
                    onRequireLogin: {
                        phoneViewModel = PhoneViewModel(authRepository: deps.authRepository)
                        otpViewModel = nil
                        registerViewModel = nil
                        route = .phone
                    }
                )
                .id(homeEpoch)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await deps.tokenRefresh.refreshAccessTokenOnForeground()
                    await DobbyPushSync.sync(api: deps.httpClient, sessionStore: deps.sessionStore)
                }
            }
        }
        .modelContainer(CartSwiftDataStack.sharedContainer)
        .onAppear {
            CrashlyticsJourney.setScreen(route.crashlyticsScreen)
        }
        .onChange(of: route) { _, newRoute in
            CrashlyticsJourney.setScreen(newRoute.crashlyticsScreen)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dobbySessionExpired)) { _ in
            switch route {
            case .splash, .phone, .otp, .register:
                // Stay on the auth flow — cancelled Home requests used to yank guests back to a spinner.
                return
            case .home:
                phoneViewModel = PhoneViewModel(authRepository: deps.authRepository)
                otpViewModel = nil
                registerViewModel = nil
                homeEpoch += 1
                route = .home
            }
        }
    }
}
