//
//  ProfileTabScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.profile.ProfileTabScreen`.
//

import SwiftUI

private enum ProfilePalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let screenBackground = Color(red: 0.97, green: 0.96, blue: 0.98)
    static let cardBackground = Color(.systemGray6)
    static let xpCardTint = Color(.systemGray5)
}

struct ProfileTabScreen: View {
    @Bindable var viewModel: ProfileTabViewModel
    let onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Perfil")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Dobby Level · XP · recompensas")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(ProfilePalette.screenBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        let s = viewModel.uiState
        switch (s.isLoading, s.error) {
        case (true, _):
            HStack {
                Spacer()
                ProgressView()
                    .tint(ProfilePalette.primary)
                    .padding(.vertical, 24)
                Spacer()
            }
        case (false, let err?) where !(err.isEmpty):
            Text(err)
                .font(.body)
                .foregroundStyle(.red)
            Button("Reintentar") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
            .tint(ProfilePalette.primary)
            .padding(.top, 12)
        default:
            profileBody(s)
        }
    }

    private func profileBody(_ s: ProfileUiState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            headerCard(s)

            xpCard(s)

            HStack(spacing: 8) {
                statChip(title: "Racha", value: "\(s.orderStreakDays) días")
                statChip(title: "Pedidos", value: "\(s.totalOrdersDelivered)")
            }

            Text("Cómo ganar XP")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)

            Text(
                "Completa pedidos, mantén una racha diaria, valora el reparto con 5 estrellas y más. " +
                    "El XP por compra tiene tope para que el nivel refleje hábito y calidad, no solo gasto."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 6)

            if !s.recentEvents.isEmpty {
                Text("Actividad reciente")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 12)

                ForEach(Array(s.recentEvents.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0)
                            .font(.body)
                        Spacer()
                        Text(row.1 >= 0 ? "+\(row.1)" : "\(row.1)")
                            .font(.body.weight(.medium))
                            .foregroundStyle(row.1 >= 0 ? ProfilePalette.primary : Color.red)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button(role: .none, action: onLogout) {
                Text("Cerrar sesión")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ProfilePalette.primary)
            .foregroundStyle(.white)
            .padding(.top, 24)
        }
    }

    private func headerCard(_ s: ProfileUiState) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(ProfilePalette.primary.opacity(0.18))
                    .frame(width: 56, height: 56)
                Text(s.avatarLetter)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ProfilePalette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.displayName)
                    .font(.title3.weight(.semibold))
                Text(s.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let phone = s.phone {
                    Text(formatPhoneDisplay(phone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProfilePalette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func xpCard(_ s: ProfileUiState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.levelName)
                        .font(.title2.weight(.bold))
                    Text("\(s.dobbyXp) XP")
                        .font(.title3)
                        .foregroundStyle(ProfilePalette.primary)
                }
                Spacer()
                Text(streakEmoji(s.orderStreakDays))
                    .font(.largeTitle)
            }

            ProgressView(value: Double(s.xpInLevelProgress))
                .tint(ProfilePalette.primary)
                .scaleEffect(x: 1, y: 1.4, anchor: .center)

            if let label = s.xpToNextLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProfilePalette.xpCardTint.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(ProfilePalette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Parity with Android `streakEmoji`.
private func streakEmoji(_ days: Int) -> String {
    if days >= 7 { return "🔥" }
    if days >= 3 { return "⭐" }
    return "🎮"
}

/// Parity with Android `formatPhoneDisplay`.
private func formatPhoneDisplay(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    guard digits.count == 10 else { return raw }
    let d = String(digits)
    let a = d.prefix(3)
    let b = d.dropFirst(3).prefix(3)
    let c = d.suffix(4)
    return "+52 \(a) \(b) \(c)"
}
