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
    /// Permanently deletes the consumer account on the server, then clears local session.
    func deleteAccount() async -> AuthResult<Void>
    /// Returns false if refresh was rejected and session was cleared.
    func syncSessionAtLaunch() async -> Bool
}
