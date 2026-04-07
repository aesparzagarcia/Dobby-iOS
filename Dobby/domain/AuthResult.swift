//
//  AuthResult.swift
//  Dobby
//

import Foundation

enum AuthResult<T: Sendable>: Sendable {
    case success(T)
    case error(String)
}

struct OtpRequestResult: Sendable {
    let userExists: Bool
}

enum VerifyOtpOutcome: Sendable {
    case loggedIn
    case requiresRegistration
}
