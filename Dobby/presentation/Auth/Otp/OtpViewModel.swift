//
//  OtpViewModel.swift
//  Dobby
//

import Foundation

private let otpLength = 6
private let resendCountdownSeconds = 600

@MainActor
@Observable
final class OtpViewModel {
    private let authRepository: AuthRepository

    let phone: String

    var digitSlots: [String] = Array(repeating: "", count: otpLength)
    var remainingSeconds = resendCountdownSeconds
    var isLoading = false
    var errorMessage: String?

    var code: String { digitSlots.joined() }

    nonisolated(unsafe) private var countdownTask: Task<Void, Never>?

    init(authRepository: AuthRepository, phone: String) {
        self.authRepository = authRepository
        self.phone = phone
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self else { return }
                    if remainingSeconds > 0 {
                        remainingSeconds -= 1
                    }
                }
            }
        }
    }

    deinit {
        countdownTask?.cancel()
    }

    /// Updates all six slots from a raw string (used by single hidden `TextField`).
    func applyOtpDigits(_ raw: String) {
        let digits = raw.filter { $0.isNumber }.prefix(otpLength)
        var slots = Array(repeating: "", count: otpLength)
        for (i, ch) in digits.enumerated() {
            slots[i] = String(ch)
        }
        digitSlots = slots
        errorMessage = nil
    }

    func verifyCode(onLoggedIn: @escaping () -> Void, onRequiresRegistration: @escaping () -> Void) {
        Task { @MainActor in
            let c = code
            if c.count < 4 {
                errorMessage = "Introduce el código que recibiste"
                return
            }
            isLoading = true
            errorMessage = nil
            let result = await authRepository.verifyOtp(phone: phone, code: c)
            isLoading = false
            switch result {
            case .success(let outcome):
                errorMessage = nil
                switch outcome {
                case .loggedIn:
                    onLoggedIn()
                case .requiresRegistration:
                    onRequiresRegistration()
                }
            case .error(let message):
                errorMessage = message
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
