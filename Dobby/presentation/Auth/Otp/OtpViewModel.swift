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
    var isResending = false
    var errorMessage: String?

    var code: String { digitSlots.joined() }
    var canResend: Bool { remainingSeconds == 0 && !isResending && !isLoading }

    private var resendDeadline: Date
    nonisolated(unsafe) private var countdownTask: Task<Void, Never>?

    init(authRepository: AuthRepository, phone: String) {
        self.authRepository = authRepository
        self.phone = phone
        resendDeadline = Date().addingTimeInterval(TimeInterval(resendCountdownSeconds))
        syncRemainingSeconds()
        startCountdownTicker()
    }

    deinit {
        countdownTask?.cancel()
    }

    /// Recomputes displayed time from wall clock (e.g. after returning from background).
    func syncRemainingSeconds() {
        remainingSeconds = max(0, Int(ceil(resendDeadline.timeIntervalSinceNow)))
    }

    private func resetResendDeadline() {
        resendDeadline = Date().addingTimeInterval(TimeInterval(resendCountdownSeconds))
        syncRemainingSeconds()
    }

    private func startCountdownTicker() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self?.syncRemainingSeconds()
                }
            }
        }
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

    func resendCode() async -> Bool {
        guard canResend else { return false }
        isResending = true
        errorMessage = nil
        defer { isResending = false }
        let result = await authRepository.requestOtp(phone: phone)
        switch result {
        case .success:
            resetResendDeadline()
            digitSlots = Array(repeating: "", count: otpLength)
            return true
        case .error(let message):
            errorMessage = message
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
