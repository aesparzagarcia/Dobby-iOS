//
//  AuthDTOs.swift
//  Dobby
//

import Foundation

// MARK: - Request OTP

struct RequestOtpRequestDTO: Encodable {
    let phone: String
}

struct RequestOtpResponseDTO: Decodable {
    let userExists: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case userExists = "user_exists"
        case message
    }
}

// MARK: - Verify OTP

struct VerifyOtpRequestDTO: Encodable {
    let phone: String
    let code: String
}

struct VerifyOtpResponseDTO: Decodable {
    let token: String?
    let refreshToken: String?
    let user: UserDTO?
    let requiresRegistration: Bool

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken
        case user
        case requiresRegistration = "requires_registration"
    }
}

struct UserDTO: Decodable {
    let id: String
    let email: String?
    let phone: String?
    let name: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, phone, name
        case lastName = "last_name"
    }
}

// MARK: - Complete registration

struct CompleteRegistrationRequestDTO: Encodable {
    let phone: String
    let name: String
    let lastName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case phone, name, email
        case lastName = "last_name"
    }
}

struct CompleteRegistrationResponseDTO: Decodable {
    let token: String
    let refreshToken: String?
    let user: UserDTO?
}

// MARK: - Refresh

struct AppRefreshRequestDTO: Encodable {
    let refreshToken: String
}

struct AppRefreshResponseDTO: Decodable {
    let token: String?
    let refreshToken: String?
}

// MARK: - Push device

struct PushOkDTO: Decodable {
    let ok: Bool?
}
