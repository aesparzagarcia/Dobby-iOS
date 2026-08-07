//
//  AppRoute.swift
//  Dobby
//

import Foundation

enum AppRoute: Equatable {
    case splash
    case phone
    case otp(phone: String, userExists: Bool)
    case register(phone: String)
    case home

    var crashlyticsScreen: String {
        switch self {
        case .splash: return "splash"
        case .phone: return "phone"
        case .otp: return "otp"
        case .register: return "register"
        case .home: return "home"
        }
    }
}
