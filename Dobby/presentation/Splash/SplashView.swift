//
//  SplashView.swift
//  Dobby
//

import SwiftUI

struct SplashView: View {
    let viewModel: SplashViewModel
    let onDecide: (Bool) -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            DobbySplashLottieView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(0.9)
        }
        .task {
            let openHome = await viewModel.resolveSplashDestination()
            onDecide(openHome)
        }
    }
}
