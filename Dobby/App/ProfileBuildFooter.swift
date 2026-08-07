//
//  ProfileBuildFooter.swift
//  Dobby
//

import SwiftUI

struct ProfileAccountSection: View {
    let isDeletingAccount: Bool
    let deleteAccountError: String?
    let onLogout: () -> Void
    let onDeleteAccount: () -> Void

    private var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Versión \(version) (\(build))"
    }

    private let deleteRed = Color(red: 0.94, green: 0.27, blue: 0.27)
    private let deleteRedBg = Color(red: 1, green: 0.945, blue: 0.949)
    private let iconGrayBg = Color(red: 0.949, green: 0.949, blue: 0.969)
    private let muted = Color(red: 0.61, green: 0.64, blue: 0.69)
    private let dark = Color(red: 0.12, green: 0.16, blue: 0.22)
    private let card = Color.white
    private let divider = Color(red: 0.91, green: 0.91, blue: 0.93)
    private let devPurple = Color(red: 0.545, green: 0.361, blue: 0.965)
    private let devPurpleBg = Color(red: 0.953, green: 0.910, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cuenta")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(dark)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                accountRow(
                    title: "Cerrar sesión",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    titleColor: dark,
                    iconTint: dark,
                    iconBackground: iconGrayBg,
                    chevronTint: muted,
                    enabled: !isDeletingAccount,
                    action: onLogout
                )
                Rectangle().fill(divider).frame(height: 1)
                accountRow(
                    title: "Eliminar cuenta",
                    systemImage: "trash",
                    titleColor: deleteRed,
                    iconTint: deleteRed,
                    iconBackground: deleteRedBg,
                    chevronTint: deleteRed,
                    enabled: !isDeletingAccount,
                    showSpinner: isDeletingAccount,
                    action: onDeleteAccount
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(versionLabel)
                .font(.footnote)
                .foregroundStyle(muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            #if DEBUG
            HStack(spacing: 8) {
                Text("Opciones de desarrollo")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(dark)
                Text("Solo desarrollo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(devPurple)
                    .clipShape(Capsule())
                Spacer(minLength: 0)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            Button {
                fatalError("Test Crash")
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(devPurpleBg)
                            .frame(width: 36, height: 36)
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(devPurple)
                    }
                    Text("Forzar crash (debug)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(devPurple)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(devPurple)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            #endif

            if let deleteAccountError, !deleteAccountError.isEmpty {
                Text(deleteAccountError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 4)
    }

    private func accountRow(
        title: String,
        systemImage: String,
        titleColor: Color,
        iconTint: Color,
        iconBackground: Color,
        chevronTint: Color,
        enabled: Bool,
        showSpinner: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconTint)
                }
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(titleColor)
                Spacer(minLength: 0)
                if showSpinner {
                    ProgressView()
                        .tint(deleteRed)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(chevronTint)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
