//
//  DobbySplashLottieView.swift
//  Dobby
//

import Lottie
import SwiftUI

private let splashLottieName = "dobby_splash"

struct DobbySplashLottieView: UIViewRepresentable {
    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.animation = LottieAnimation.named(splashLottieName, bundle: .main)
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore
        view.backgroundColor = .clear
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.animation == nil, let animation = LottieAnimation.named(splashLottieName, bundle: .main) {
            uiView.animation = animation
            uiView.play()
        }
    }
}
