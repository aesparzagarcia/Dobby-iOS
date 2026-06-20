//
//  SplashView.swift
//  Dobby
//

import SwiftUI

struct SplashView: View {
    let viewModel: SplashViewModel
    let onDecide: (Bool) -> Void

    /// Side length of the centered app icon (132pt baseline −20%).
    private let splashLogoSide: CGFloat = 106

    private var splashLogoAssetName: String {
        AppConfiguration.isDevEnvironment ? "SplashLogo-Dev" : "SplashLogo-Prod"
    }

    private var splashBackgroundColor: Color {
        AppConfiguration.isDevEnvironment
            ? Color(red: 252 / 255, green: 99 / 255, blue: 3 / 255)
            : .black
    }

    var body: some View {
        ZStack {
            splashBackgroundColor.ignoresSafeArea()

            Image(splashLogoAssetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: splashLogoSide, height: splashLogoSide)
        }
        .task {
            let openHome = await viewModel.resolveSplashDestination()
            onDecide(openHome)
        }
    }
}
