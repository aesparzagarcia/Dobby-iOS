//
//  ProfileTabScreen.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.presentation.ui.main.profile.ProfileTabScreen`.
//

import SwiftUI
import UIKit

private enum ProfilePalette {
    static let primary = DobbyBrandColor.primary
    static let light = DobbyBrandColor.light
    static let dark = DobbyBrandColor.dark
    static let muted = DobbyBrandColor.textSecondary
    static let card = Color.white
    static let logoutBg = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let logoutText = Color(red: 0.94, green: 0.27, blue: 0.27)
}

private struct ProfileMission: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let xpLabel: String
    let systemImage: String
}

private let profileTodayMissions: [ProfileMission] = [
    ProfileMission(id: "order", title: "Haz un pedido", subtitle: "Completa un pedido hoy", xpLabel: "+20 XP", systemImage: "bag.fill"),
    ProfileMission(id: "streak", title: "Mantén tu racha", subtitle: "Pide al menos 1 día seguido", xpLabel: "+5 XP", systemImage: "flame.fill"),
    ProfileMission(id: "rate", title: "Valora tu entrega", subtitle: "Califica con 5 estrellas", xpLabel: "+5 XP", systemImage: "star.fill"),
]

private struct ProfileBadge: Identifiable {
    let id: String
    let title: String
    let unlocked: Bool
    let color: Color
    let systemImage: String
}

private enum ProfileStackRoute: Hashable {
    case orderHistory
    case orderTracking(orderId: String)
}

private let profileSupportURL = URL(string: "https://dobby-frontend-wwru.onrender.com/soporte")!

struct ProfileTabScreen: View {
    @Bindable var viewModel: ProfileTabViewModel
    var favoritesCount: Int
    let orderRepository: OrderRepository
    let directionsRepository: DirectionsRepository
    let httpClient: DobbyHTTPClient
    @Binding var mainTabBarHidden: Bool
    let onGoHome: () -> Void
    let onLogout: () -> Void
    let onRequireLogin: () -> Void

    @Environment(\.openURL) private var openURL

    @State private var navigationPath: [ProfileStackRoute] = []
    @State private var orderHistoryViewModel: OrderHistoryViewModel?
    @State private var showDeleteConfirm = false
    @State private var showDeleteFinalConfirm = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            profileRoot
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ProfileStackRoute.self) { route in
                    switch route {
                    case .orderHistory:
                        OrderHistoryScreen(
                            viewModel: orderHistoryViewModel ?? OrderHistoryViewModel(orderRepository: orderRepository),
                            onOrderTap: { orderId in
                                navigationPath.append(.orderTracking(orderId: orderId))
                            }
                        )
                    case .orderTracking(let orderId):
                        OrderTrackingScreen(
                            orderId: orderId,
                            orderRepository: orderRepository,
                            directionsRepository: directionsRepository,
                            http: httpClient,
                            onBack: { popNavigation() },
                            onFinish: { popNavigation() }
                        )
                    }
                }
        }
        .onAppear {
            if orderHistoryViewModel == nil {
                orderHistoryViewModel = OrderHistoryViewModel(orderRepository: orderRepository)
            }
            viewModel.updateFavoritesCount(favoritesCount)
            viewModel.refresh()
            syncMainTabBarHidden()
        }
        .onChange(of: favoritesCount) { _, newValue in
            viewModel.updateFavoritesCount(newValue)
        }
        .onChange(of: navigationPath) { _, _ in
            syncMainTabBarHidden()
        }
        .alert("Eliminar cuenta", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Continuar", role: .destructive) {
                showDeleteFinalConfirm = true
            }
        } message: {
            Text("Se eliminará tu cuenta y los datos personales asociados de forma permanente. Esta acción no se puede deshacer.")
        }
        .alert("Confirmar eliminación", isPresented: $showDeleteFinalConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar definitivamente", role: .destructive) {
                Task {
                    if await viewModel.deleteAccount() {
                        onLogout()
                    }
                }
            }
        } message: {
            Text("¿Seguro que quieres eliminar tu cuenta de Dobbi?")
        }
    }

    private var profileRoot: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Perfil")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(ProfilePalette.dark)
                    Spacer()
                    Button {
                        openAppSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.body)
                            .foregroundStyle(ProfilePalette.dark)
                    }
                    .buttonStyle(.plain)
                }

                Text("Sigue acumulando XP y desbloquea recompensas increíbles 🎉")
                    .font(.body)
                    .foregroundStyle(ProfilePalette.muted)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(ProfilePalette.light.ignoresSafeArea())
    }

    private func syncMainTabBarHidden() {
        mainTabBarHidden = !navigationPath.isEmpty
    }

    private func popNavigation() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    @ViewBuilder
    private var content: some View {
        let s = viewModel.uiState
        if s.isGuest {
            guestBody
        } else {
            switch (s.isLoading, s.error) {
            case (true, _):
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ProfilePalette.primary)
                        .padding(.vertical, 32)
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
    }

    private var guestBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inicia sesión para ver tu perfil, historial de pedidos y recompensas.")
                .font(.body)
                .foregroundStyle(ProfilePalette.muted)

            Button(action: onRequireLogin) {
                Text("Iniciar sesión")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ProfilePalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            whiteCard {
                Button {
                    openURL(profileSupportURL)
                } label: {
                    menuRow(title: "Ayuda y soporte", systemImage: "questionmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private func profileBody(_ s: ProfileUiState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            heroCard(s)

            HStack(spacing: 8) {
                quickStat(
                    title: "Racha",
                    value: streakValueLabel(s.orderStreakDays),
                    systemImage: "flame.fill",
                    tint: Color(red: 1, green: 0.54, blue: 0.24),
                    background: Color(red: 1, green: 0.97, blue: 0.93)
                )
                Button {
                    navigationPath.append(.orderHistory)
                } label: {
                    quickStat(
                        title: "Pedidos",
                        value: ordersValueLabel(s.totalOrdersDelivered),
                        systemImage: "bag.fill",
                        tint: ProfilePalette.primary,
                        background: ProfilePalette.light
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                quickStat(
                    title: "Favoritos",
                    value: "\(s.favoritesCount) favoritos",
                    systemImage: "heart.fill",
                    tint: Color(red: 0.94, green: 0.27, blue: 0.27),
                    background: Color(red: 1, green: 0.95, blue: 0.96)
                )
                quickStat(
                    title: "Insignias",
                    value: "\(s.badgesUnlockedCount) insignias",
                    systemImage: "star.fill",
                    tint: Color(red: 0.55, green: 0.36, blue: 0.96),
                    background: Color(red: 0.95, green: 0.91, blue: 1)
                )
            }

            sectionHeader("Misiones de hoy")
            whiteCard {
                ForEach(Array(profileTodayMissions.enumerated()), id: \.element.id) { index, mission in
                    Button {
                        onGoHome()
                    } label: {
                        missionRow(mission)
                    }
                    .buttonStyle(.plain)
                    if index < profileTodayMissions.count - 1 {
                        menuDivider
                    }
                }
            }

            if !s.recentEvents.isEmpty {
                sectionHeader("Actividad reciente")
                whiteCard {
                    ForEach(s.recentEvents, id: \.self) { event in
                        activityRow(event)
                    }
                }
            }

            sectionHeader("Tus insignias")
            HStack {
                ForEach(profileBadges(for: s)) { badge in
                    badgeChip(badge)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            whiteCard {
                Button {
                    openAppSettings()
                } label: {
                    menuRow(title: "Notificaciones", systemImage: "bell.fill")
                }
                .buttonStyle(.plain)
                menuDivider
                Button {
                    openURL(profileSupportURL)
                } label: {
                    menuRow(title: "Ayuda y soporte", systemImage: "questionmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            Button(action: onLogout) {
                Text("Cerrar sesión")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ProfilePalette.logoutText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ProfilePalette.logoutBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .disabled(s.isDeletingAccount)

            Button {
                showDeleteConfirm = true
            } label: {
                Group {
                    if s.isDeletingAccount {
                        ProgressView()
                            .tint(ProfilePalette.logoutText)
                    } else {
                        Text("Eliminar cuenta")
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(ProfilePalette.logoutText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .disabled(s.isDeletingAccount)

            if let deleteErr = s.deleteAccountError, !deleteErr.isEmpty {
                Text(deleteErr)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func heroCard(_ s: ProfileUiState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 52, height: 52)
                    Text(s.avatarLetter)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(s.email)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                    if let phone = s.phone {
                        Text(formatPhoneDisplay(phone))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.caption.weight(.semibold))
                Text("\(s.levelName) • Nivel \(s.levelNumber)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DobbyBrandColor.dark.opacity(0.35))
            .clipShape(Capsule())

            Text("\(s.dobbyXp) XP")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            ProgressView(value: Double(s.xpInLevelProgress))
                .tint(.white)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
                .background(Color.white.opacity(0.28))
                .clipShape(Capsule())

            if let label = s.xpToNextLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                ProfilePalette.primary
                Image("DobbyCard")
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func quickStat(title: String, value: String, systemImage: String, tint: Color, background: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(ProfilePalette.dark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(ProfilePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(ProfilePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ProfilePalette.dark)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func whiteCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProfilePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func missionRow(_ mission: ProfileMission) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ProfilePalette.light)
                    .frame(width: 40, height: 40)
                Image(systemName: mission.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ProfilePalette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(mission.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ProfilePalette.dark)
                Text(mission.subtitle)
                    .font(.caption)
                    .foregroundStyle(ProfilePalette.muted)
            }
            Spacer(minLength: 4)
            Text(mission.xpLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(ProfilePalette.primary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ProfilePalette.muted)
        }
        .padding(.vertical, 10)
    }

    private func activityRow(_ event: ProfileRecentEvent) -> some View {
        let style = activityStyle(for: event.label)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(style.background)
                    .frame(width: 40, height: 40)
                Image(systemName: style.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(style.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ProfilePalette.dark)
                Text(event.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(ProfilePalette.muted)
            }
            Spacer(minLength: 4)
            Text(event.delta >= 0 ? "+\(event.delta) XP" : "\(event.delta) XP")
                .font(.caption.weight(.bold))
                .foregroundStyle(event.delta >= 0 ? ProfilePalette.primary : ProfilePalette.logoutText)
        }
        .padding(.vertical, 8)
    }

    private func badgeChip(_ badge: ProfileBadge) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(badge.unlocked ? badge.color : Color(red: 0.90, green: 0.91, blue: 0.92))
                    .frame(width: 72, height: 64)
                Image(systemName: badge.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(badge.unlocked ? .white : ProfilePalette.muted)
            }
            Text(badge.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(badge.unlocked ? ProfilePalette.dark : ProfilePalette.muted)
                .multilineTextAlignment(.center)
                .frame(width: 88)
        }
    }

    private func menuRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(ProfilePalette.primary)
                .frame(width: 22)
            Text(title)
                .font(.body)
                .foregroundStyle(ProfilePalette.dark)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ProfilePalette.muted)
        }
        .padding(.vertical, 14)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color(red: 0.91, green: 0.91, blue: 0.93))
            .frame(height: 1)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private func profileBadges(for s: ProfileUiState) -> [ProfileBadge] {
    [
        ProfileBadge(
            id: "first",
            title: "Primer pedido",
            unlocked: s.totalOrdersDelivered >= 1,
            color: Color(red: 1, green: 0.54, blue: 0.24),
            systemImage: "pawprint.fill"
        ),
        ProfileBadge(
            id: "frequent",
            title: "Cliente frecuente",
            unlocked: s.totalOrdersDelivered >= 3,
            color: DobbyBrandColor.warning,
            systemImage: "star.fill"
        ),
        ProfileBadge(
            id: "streak",
            title: "Racha inicial",
            unlocked: s.orderStreakDays >= 1,
            color: Color(red: 0.55, green: 0.36, blue: 0.96),
            systemImage: "flame.fill"
        ),
    ]
}

private struct ActivityStyle {
    let systemImage: String
    let tint: Color
    let background: Color
}

private func activityStyle(for label: String) -> ActivityStyle {
    if label.localizedCaseInsensitiveContains("pedido") {
        return ActivityStyle(systemImage: "pawprint.fill", tint: DobbyBrandColor.primary, background: DobbyBrandColor.light)
    }
    if label.localizedCaseInsensitiveContains("compra") {
        return ActivityStyle(systemImage: "bag.fill", tint: Color(red: 0.13, green: 0.77, blue: 0.37), background: Color(red: 0.86, green: 0.99, blue: 0.91))
    }
    if label.localizedCaseInsensitiveContains("racha") {
        return ActivityStyle(systemImage: "flame.fill", tint: Color(red: 1, green: 0.54, blue: 0.24), background: Color(red: 1, green: 0.97, blue: 0.93))
    }
    return ActivityStyle(systemImage: "megaphone.fill", tint: Color(red: 0.55, green: 0.36, blue: 0.96), background: Color(red: 0.95, green: 0.91, blue: 1))
}

private func streakValueLabel(_ days: Int) -> String {
    days == 1 ? "1 día" : "\(days) días"
}

private func ordersValueLabel(_ count: Int) -> String {
    count == 1 ? "1 pedido" : "\(count) pedidos"
}

private func formatPhoneDisplay(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    guard digits.count == 10 else { return raw }
    let d = String(digits)
    let a = d.prefix(3)
    let b = d.dropFirst(3).prefix(3)
    let c = d.suffix(4)
    return "+52 \(a) \(b) \(c)"
}
