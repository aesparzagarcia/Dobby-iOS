//
//  OtpScreen.swift
//  Dobby
//

import SwiftUI

private let phoneTeal = Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
private let backSurface = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
private let circleOuter = Color(red: 0xD1 / 255, green: 0xD5 / 255, blue: 0xDB / 255)
private let circleInner = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
private let timerLabel = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
private let timerValue = Color(red: 0x37 / 255, green: 0x41 / 255, blue: 0x51 / 255)

private func formatPhoneForDisplay(_ phone: String) -> String {
    let digits = phone.filter { $0.isNumber }
    if digits.count == 10 {
        return "+52 \(digits)"
    }
    let p = phone.trimmingCharacters(in: .whitespaces)
    if p.hasPrefix("+52"), p.count > 3 {
        return "+52 \(p.dropFirst(3).filter { $0.isNumber })"
    }
    return p.isEmpty ? phone : p
}

private func formatMmSs(_ totalSeconds: Int) -> String {
    let t = max(0, totalSeconds)
    let m = t / 60
    let s = t % 60
    return String(format: "%d:%02d", m, s)
}

struct OtpScreen: View {
    @Bindable var viewModel: OtpViewModel
    var onLoggedIn: () -> Void
    var onRequiresRegistration: (String) -> Void
    var onBack: () -> Void

    /// Single source for the hidden field; digits sync into `viewModel.digitSlots`.
    @State private var otpEntry = ""
    @FocusState private var otpFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(backSurface)
                        .clipShape(Circle())
                }
                .padding(.top, 8)

                Spacer().frame(height: 20)

                Text("Introduce el código que enviamos 👀")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)

                Spacer().frame(height: 10)

                Text("A TU NÚMERO DE CELULAR")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(.black)

                Spacer().frame(height: 4)

                Text(formatPhoneForDisplay(viewModel.phone))
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundStyle(phoneTeal)

                Spacer().frame(height: 36)

                ZStack {
                    HStack(spacing: 10) {
                        ForEach(0 ..< 6, id: \.self) { index in
                            otpDigitCircle(
                                digit: index < viewModel.digitSlots.count ? viewModel.digitSlots[index] : "",
                                isActive: otpFieldFocused && index == otpEntry.count && otpEntry.count < 6
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    TextField("", text: $otpEntry)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($otpFieldFocused)
                        .opacity(0.02)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(Rectangle())
                }
                .onTapGesture {
                    otpFieldFocused = true
                }

                if let err = viewModel.errorMessage {
                    Spacer().frame(height: 16)
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isLoading {
                    Spacer().frame(height: 24)
                    HStack {
                        Spacer()
                        ProgressView().tint(phoneTeal)
                        Spacer()
                    }
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text("Podrás solicitar un nuevo código en")
                    .font(.body)
                    .foregroundStyle(timerLabel)
                Text(formatMmSs(viewModel.remainingSeconds))
                    .font(.system(.title3, design: .default, weight: .bold))
                    .foregroundStyle(timerValue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .onAppear {
            otpFieldFocused = true
        }
        .onChange(of: otpEntry) { _, new in
            let filtered = String(new.filter { $0.isNumber }.prefix(6))
            if filtered != new {
                otpEntry = filtered
                return
            }
            viewModel.applyOtpDigits(filtered)
            guard filtered.count == 6 else { return }
            guard !viewModel.isLoading else { return }
            guard viewModel.errorMessage == nil else { return }
            viewModel.verifyCode(
                onLoggedIn: onLoggedIn,
                onRequiresRegistration: { onRequiresRegistration(viewModel.phone) }
            )
        }
    }

    @ViewBuilder
    private func otpDigitCircle(digit: String, isActive: Bool) -> some View {
        let display = String(digit.prefix(1))
        ZStack {
            Circle()
                .stroke(isActive ? phoneTeal : circleOuter, lineWidth: isActive ? 2 : 1)
                .background(Circle().fill(Color.white))
            Circle()
                .stroke(circleInner, lineWidth: 1)
                .padding(3)
            Text(display)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(width: 48, height: 48)
        .frame(maxWidth: .infinity)
    }
}
