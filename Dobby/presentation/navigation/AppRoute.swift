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
}
