//
//  CouponsLottiePreviewScreen.swift
//  Dobby
//

import SwiftUI

struct CouponsLottiePreviewScreen: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DobbyBrandColor.dark)
                    .padding(12)
            }
            .buttonStyle(.plain)

            Text("Cupones")
                .font(.title3.weight(.bold))
                .foregroundStyle(DobbyBrandColor.dark)
                .padding(.horizontal, 16)

            Text("Vista previa skeleton loader")
                .font(.body)
                .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                .padding(.horizontal, 16)
                .padding(.top, 4)

            MarketplaceSkeletonLottieView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
