//
//  NavigationBackButton.swift
//  Dobby
//
//  Shared back control with a reliable 44×44 hit target (HIG).
//

import SwiftUI

struct NavigationBackButton: View {
    var accessibilityLabel: String = "Atrás"
    var tint: Color = DobbyPureScale.onyx
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
