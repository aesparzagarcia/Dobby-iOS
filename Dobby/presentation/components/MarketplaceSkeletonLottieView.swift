//
//  MarketplaceSkeletonLottieView.swift
//  Dobby
//

import Lottie
import SwiftUI

struct MarketplaceSkeletonLottieView: UIViewRepresentable {
    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.animation = LottieAnimation.named("marketplace_skeleton_loader", bundle: .main)
        view.contentMode = .scaleAspectFill
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore
        view.backgroundColor = .clear
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.animation == nil,
           let animation = LottieAnimation.named("marketplace_skeleton_loader", bundle: .main) {
            uiView.animation = animation
            uiView.play()
        }
    }
}
