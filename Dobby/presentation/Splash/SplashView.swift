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
            ProgressView()
                .controlSize(.large)
        }
        .task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let openHome = await viewModel.shouldOpenHomeAfterSplash()
            onDecide(openHome)
        }
    }
}
