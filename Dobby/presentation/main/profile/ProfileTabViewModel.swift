//
//  ProfileTabViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.profile.ProfileTabViewModel`.
//

import Foundation

struct ProfileRecentEvent: Sendable, Hashable {
    let label: String
    let delta: Int
    let timeAgo: String
}

/// Parity with Android `ProfileUiState`.
struct ProfileUiState: Sendable {
    var isLoading: Bool = true
    var error: String?
    /// Guest browse: not signed in — show login CTA instead of gamification.
    var isGuest: Bool = false
    var displayName: String = ""
    var email: String = ""
    var phone: String?
    var avatarLetter: String = "?"
    var dobbyXp: Int = 0
    var levelKey: String = "EXPLORADOR"
    var levelName: String = ""
    var xpInLevelProgress: Float = 0
    var xpToNextLabel: String?
    var orderStreakDays: Int = 0
    var totalOrdersDelivered: Int = 0
    var favoritesCount: Int = 0
    var recentEvents: [ProfileRecentEvent] = []
    var isDeletingAccount: Bool = false
    var deleteAccountError: String?

    var levelNumber: Int {
        consumerLevelNumber(levelKey)
    }

    var badgesUnlockedCount: Int {
        [
            totalOrdersDelivered >= 1,
            totalOrdersDelivered >= 3,
            orderStreakDays >= 1,
        ].filter { $0 }.count
    }
}

@MainActor
@Observable
final class ProfileTabViewModel {
    private let profileRepository: ProfileRepository
    private let authRepository: AuthRepository
    private let http: DobbyHTTPClient

    var uiState = ProfileUiState()

    init(profileRepository: ProfileRepository, authRepository: AuthRepository, http: DobbyHTTPClient) {
        self.profileRepository = profileRepository
        self.authRepository = authRepository
        self.http = http
        refresh()
    }

    func refresh() {
        Task {
            uiState.isLoading = true
            uiState.error = nil
            uiState.deleteAccountError = nil
            guard authRepository.isLoggedIn else {
                uiState = ProfileUiState(
                    isLoading: false,
                    error: nil,
                    isGuest: true,
                    favoritesCount: uiState.favoritesCount
                )
                return
            }
            switch await profileRepository.getGamification() {
            case .success(let g):
                let next = g.xpForNextLevel
                let start = g.xpAtLevelStart
                let current = g.dobbyXp
                let progress: Float
                if let next, next > start {
                    let p = Float(current - start) / Float(next - start)
                    progress = min(max(p, 0), 1)
                } else {
                    progress = 1
                }
                let xpToNext: Int?
                if let next {
                    xpToNext = max(0, next - current)
                } else {
                    xpToNext = nil
                }
                let namePart = g.name.flatMap { raw -> String? in
                    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
                let lastPart = g.lastName.flatMap { raw -> String? in
                    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
                let fullName = [namePart, lastPart].compactMap { $0 }.joined(separator: " ")
                let display: String
                if fullName.isEmpty {
                    let local = g.email.split(separator: "@").first.map(String.init) ?? ""
                    display = local.isEmpty ? "Usuario" : local
                } else {
                    display = fullName
                }
                let initial = display.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
                let events = g.recentEvents.map { e in
                    ProfileRecentEvent(
                        label: reasonLabelEs(e.reason),
                        delta: e.delta,
                        timeAgo: formatTimeAgoEs(e.createdAt)
                    )
                }
                uiState = ProfileUiState(
                    isLoading: false,
                    error: nil,
                    isGuest: false,
                    displayName: display,
                    email: g.email,
                    phone: g.phone.flatMap { $0.isEmpty ? nil : $0 },
                    avatarLetter: initial,
                    dobbyXp: current,
                    levelKey: g.levelKey,
                    levelName: g.levelName,
                    xpInLevelProgress: progress,
                    xpToNextLabel: xpToNext.map { "\($0) XP para el siguiente nivel" },
                    orderStreakDays: g.orderStreakDays,
                    totalOrdersDelivered: g.totalOrdersDelivered,
                    favoritesCount: uiState.favoritesCount,
                    recentEvents: events
                )
            case .failure(let error):
                if case .notAuthenticated = error {
                    uiState = ProfileUiState(
                        isLoading: false,
                        isGuest: true,
                        favoritesCount: uiState.favoritesCount
                    )
                    return
                }
                uiState.isLoading = false
                uiState.isGuest = false
                uiState.error = profileAuthErrorShouldSuppress(error) ? nil : message(for: error)
            }
        }
    }

    func updateFavoritesCount(_ count: Int) {
        uiState.favoritesCount = count
    }

    /// Deletes the account on the server. Returns `true` when the caller should leave the signed-in UI (same as logout).
    func deleteAccount() async -> Bool {
        uiState.isDeletingAccount = true
        uiState.deleteAccountError = nil
        let result = await authRepository.deleteAccount()
        uiState.isDeletingAccount = false
        switch result {
        case .success:
            return true
        case .error(let message):
            uiState.deleteAccountError = message
            return false
        }
    }

    private func profileAuthErrorShouldSuppress(_ error: ProfileRepositoryError) -> Bool {
        switch error {
        case .notAuthenticated:
            return true
        case .http(let he):
            return he.shouldSuppressUserFacingMessage
        }
    }

    private func message(for error: ProfileRepositoryError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sesión no válida. Vuelve a iniciar sesión."
        case .http(let he):
            return http.userFacingMessage(from: he)
        }
    }

    private func reasonLabelEs(_ reason: String) -> String {
        switch reason {
        case "purchase": return "Compra completada"
        case "first_order": return "Primer pedido"
        case "peak_hour": return "Hora pico"
        case "order_streak": return "Racha de pedidos"
        case "rate_delivery": return "Valoraste tu entrega"
        default: return reason
        }
    }
}

func consumerLevelNumber(_ levelKey: String) -> Int {
    let order = ["EXPLORADOR", "FRECUENTE", "FAN", "VIP", "DOBBY_MASTER"]
    let idx = order.firstIndex(of: levelKey.uppercased()) ?? 0
    return idx + 1
}

private func formatTimeAgoEs(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: iso)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: iso)
    }
    guard let date else { return "Reciente" }
    let minutes = Int(Date().timeIntervalSince(date) / 60)
    if minutes < 1 { return "Hace un momento" }
    if minutes < 60 { return "Hace \(minutes) min" }
    if minutes < 60 * 24 { return "Hace \(minutes / 60) h" }
    if minutes < 60 * 24 * 2 { return "Hace 1 día" }
    if minutes < 60 * 24 * 7 { return "Hace \(minutes / (60 * 24)) días" }
    return "Hace más de una semana"
}
