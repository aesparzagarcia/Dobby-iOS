//
//  AuthRepository.swift
//  Dobby
//

import Foundation

protocol AuthRepository: Sendable {
    var isLoggedIn: Bool { get }

    func requestOtp(phone: String) async -> AuthResult<OtpRequestResult>
    func verifyOtp(phone: String, code: String) async -> AuthResult<VerifyOtpOutcome>
    func completeRegistration(phone: String, name: String, lastName: String, email: String) async -> AuthResult<Void>
    func logout() async
    /// Returns false if refresh was rejected and session was cleared.
    func syncSessionAtLaunch() async -> Bool
}
