//
//  ProfileTabViewModel.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.viewmodel.main.profile.ProfileTabViewModel`.
//

import Foundation

/// Parity with Android `ProfileUiState`.
struct ProfileUiState: Sendable {
    var isLoading: Bool = true
    var error: String?
    var displayName: String = ""
    var email: String = ""
    var phone: String?
    var avatarLetter: String = "?"
    var dobbyXp: Int = 0
    var levelName: String = ""
    var xpInLevelProgress: Float = 0
    var xpToNextLabel: String?
    var orderStreakDays: Int = 0
    var totalOrdersDelivered: Int = 0
    var recentEvents: [(String, Int)] = []
}

@MainActor
@Observable
final class ProfileTabViewModel {
    private let profileRepository: ProfileRepository
    private let http: DobbyHTTPClient

    var uiState = ProfileUiState()

    init(profileRepository: ProfileRepository, http: DobbyHTTPClient) {
        self.profileRepository = profileRepository
        self.http = http
        refresh()
    }

    func refresh() {
        Task {
            uiState.isLoading = true
            uiState.error = nil
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
                    (reasonLabelEs(e.reason), e.delta)
                }
                uiState = ProfileUiState(
                    isLoading: false,
                    error: nil,
                    displayName: display,
                    email: g.email,
                    phone: g.phone.flatMap { $0.isEmpty ? nil : $0 },
                    avatarLetter: initial,
                    dobbyXp: current,
                    levelName: g.levelName,
                    xpInLevelProgress: progress,
                    xpToNextLabel: xpToNext.map { "\($0) XP al siguiente nivel" },
                    orderStreakDays: g.orderStreakDays,
                    totalOrdersDelivered: g.totalOrdersDelivered,
                    recentEvents: events
                )
            case .failure(let error):
                uiState.isLoading = false
                uiState.error = profileAuthErrorShouldSuppress(error) ? nil : message(for: error)
            }
        }
    }

    /// Local helper (avoids relying on `ProfileRepositoryError` computed members across module/protocol boundaries).
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

    /// Parity with Android `reasonLabelEs`.
    private func reasonLabelEs(_ reason: String) -> String {
        switch reason {
        case "purchase": return "Compra"
        case "first_order": return "Primer pedido"
        case "peak_hour": return "Hora pico"
        case "order_streak": return "Racha de pedidos"
        case "rate_delivery": return "Valorar reparto"
        default: return reason
        }
    }
}
