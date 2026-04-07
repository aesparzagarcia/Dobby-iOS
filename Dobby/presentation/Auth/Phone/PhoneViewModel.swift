//
//  PhoneViewModel.swift
//  Dobby
//

import Foundation

private let mxNationalLength = 10

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
        let digits = raw.filter { $0.isNumber }.prefix(mxNationalLength)
        nationalDigits = String(digits)
        errorMessage = nil
    }

    func sendCode(onResult: @escaping (String, Bool) -> Void) {
        Task { @MainActor in
            let phone = nationalDigits
            if phone.count < mxNationalLength {
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
