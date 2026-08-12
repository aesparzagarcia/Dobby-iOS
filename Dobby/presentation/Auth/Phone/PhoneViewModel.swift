//
//  PhoneViewModel.swift
//  Dobby
//

import Foundation

/// Dígitos nacionales (México) sin lada; máximo 10.
enum PhoneNationalInput {
    static let maxDigits = 10
}

@MainActor
@Observable
final class PhoneViewModel {
    private let authRepository: AuthRepository

    var nationalDigits = ""
    var isLoading = false
    var errorMessage: String?

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func onPhoneChange(_ raw: String) {
        let digits = String(raw.filter(\.isNumber).prefix(PhoneNationalInput.maxDigits))
        if nationalDigits != digits {
            nationalDigits = digits
        }
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    func sendCode(onResult: @escaping (String, Bool) -> Void) {
        Task { @MainActor in
            let phone = nationalDigits
            if phone.count < PhoneNationalInput.maxDigits {
                errorMessage = "Introduce un número de 10 dígitos"
                return
            }
            isLoading = true
            errorMessage = nil
            let result = await authRepository.requestOtp(phone: phone)
            isLoading = false
            switch result {
            case .success(let data):
                errorMessage = nil
                onResult(phone, data.userExists)
            case .error(let message):
                errorMessage = message
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
