//
//  RegisterUserViewModel.swift
//  Dobby
//

import Foundation

@MainActor
@Observable
final class RegisterUserViewModel {
    private let authRepository: AuthRepository

    let phone: String

    var name = ""
    var lastName = ""
    var email = ""
    var isLoading = false
    var errorMessage: String?

    init(authRepository: AuthRepository, phone: String) {
        self.authRepository = authRepository
        self.phone = phone
    }

    func onNameChange(_ value: String) {
        name = value
        errorMessage = nil
    }

    func onLastNameChange(_ value: String) {
        lastName = value
        errorMessage = nil
    }

    func onEmailChange(_ value: String) {
        email = value
        errorMessage = nil
    }

    func submit(onSuccess: @escaping () -> Void) {
        Task { @MainActor in
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "El nombre es obligatorio"
                return
            }
            if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "El apellido es obligatorio"
                return
            }
            let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if em.isEmpty {
                errorMessage = "El correo es obligatorio"
                return
            }
            if !Self.isValidEmail(em) {
                errorMessage = "Introduce un correo válido"
                return
            }
            isLoading = true
            errorMessage = nil
            let result = await authRepository.completeRegistration(
                phone: phone,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: em
            )
            isLoading = false
            switch result {
            case .success(_):
                errorMessage = nil
                onSuccess()
            case .error(let message):
                errorMessage = message
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private static func isValidEmail(_ s: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}
