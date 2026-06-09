//
//  DobbyBrandColor.swift
//  Dobby
//
//  Escala pura + tokens semánticos (paridad con Android `DobbyPureScale` / `DobbyColors`).
//

import SwiftUI

/// De Onyx a Pure — elegante, atemporal y legible.
enum DobbyPureScale {
    /// `#0D0D0D`
    static let onyx = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    /// `#1F1F1F`
    static let carbon = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
    /// `#3A3A3A`
    static let graphite = Color(red: 58 / 255, green: 58 / 255, blue: 58 / 255)
    /// `#8A8A8A`
    static let ash = Color(red: 138 / 255, green: 138 / 255, blue: 138 / 255)
    /// `#E8E8E8`
    static let mist = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)
    /// `#F5F5F5`
    static let fog = Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
    /// `#FFFFFF`
    static let pure = Color.white
}

enum DobbyBrandColor {
    static let navHeader = DobbyPureScale.onyx
    static let textPrimary = DobbyPureScale.onyx
    static let textSecondary = DobbyPureScale.ash
    static let iconBorder = DobbyPureScale.graphite
    static let cardSurface = DobbyPureScale.pure
    static let screenBackground = DobbyPureScale.fog
    static let divider = DobbyPureScale.mist
    static let surfaceMuted = DobbyPureScale.fog

    /// CTAs principales
    static let primary = DobbyPureScale.onyx
    static let onPrimary = DobbyPureScale.pure

    /// Compatibilidad con código existente
    static let dark = DobbyPureScale.onyx
    static let light = DobbyPureScale.fog
    static let carbon = DobbyPureScale.carbon

    static let accent = Color(red: 0, green: 194 / 255, blue: 168 / 255)
    static let warning = Color(red: 1, green: 184 / 255, blue: 0)

    static let primaryLightBackground = light
    static let primaryHalo = primary.opacity(0.22)
    static var warningBackground: Color { warning.opacity(0.15) }
}
