//
//  DobbyBrandColor.swift
//  Dobby
//
//  Brand palette — parity with Android `DobbyColors`.
//

import SwiftUI

enum DobbyBrandColor {
    /// `#0061FF`
    static let primary = Color(red: 0, green: 97 / 255, blue: 1)
    /// `#00C2A8`
    static let accent = Color(red: 0, green: 194 / 255, blue: 168 / 255)
    /// `#F0F4FF`
    static let light = Color(red: 240 / 255, green: 244 / 255, blue: 1)
    /// `#1D2B4F`
    static let dark = Color(red: 29 / 255, green: 43 / 255, blue: 79 / 255)
    /// `#FFB800`
    static let warning = Color(red: 1, green: 184 / 255, blue: 0)

    static let primaryLightBackground = light
    static let primaryHalo = primary.opacity(0.22)
    static var warningBackground: Color { warning.opacity(0.15) }
}
