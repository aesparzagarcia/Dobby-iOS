//
//  FeaturedPlacesComponents.swift
//  Dobby
//
//  Parity with Android `FeaturedPlacesComponents.kt`.
//

import SwiftUI

private enum FeaturedPlacesPalette {
    static let mutedText = Color(red: 0.42, green: 0.45, blue: 0.50)
}

struct FeaturedPlacesHeader: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .accessibilityLabel("Atrás")

            VStack(alignment: .leading, spacing: 4) {
                Text("Destacados")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Descubre restaurantes, tiendas y servicios cerca de ti.")
                    .font(.subheadline)
                    .foregroundStyle(FeaturedPlacesPalette.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}
