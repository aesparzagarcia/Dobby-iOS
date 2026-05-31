//
//  HomeLayoutConstants.swift
//  Dobby
//

import UIKit

enum HomeLayoutConstants {
    static let destacadosPreviewLimit = 4
    static let bestSellersPreviewLimit = 4
    /// Clearance for the floating tab bar (~58pt) + bottom padding (8pt) + small gap (8pt).
    static let mainTabContentBottomInset: CGFloat = 72
    static let featuredPlaceCardScale: CGFloat = 0.8
    static let productCardScale: CGFloat = 0.85
    static let categoryRowScale: CGFloat = 0.9

    static func featuredCardWidth(screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGFloat {
        CGFloat(max(160, min(198, Int(screenWidth * 0.56 * featuredPlaceCardScale))))
    }

    static func productCardWidth(featuredWidth: CGFloat) -> CGFloat {
        CGFloat(Int(featuredWidth * 0.9 * productCardScale))
    }
}
