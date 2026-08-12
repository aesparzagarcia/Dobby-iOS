//
//  PhoneScreen.swift
//  Dobby
//

import SwiftUI

private let subtitleBlack = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
private let backSurface = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
private let termsLinkBlue = Color(red: 0x00 / 255, green: 0x7A / 255, blue: 0xFF / 255)
private let termsURL = URL(string: "https://dobby-frontend-wwru.onrender.com/terminos-y-condiciones")!
private let privacyURL = URL(string: "https://dobby-frontend-wwru.onrender.com/aviso-de-privacidad")!
/// Placeholder del celular: más oscuro que el gris secundario del sistema.
private let phoneFieldPlaceholderColor = Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x55 / 255)

struct PhoneScreen: View {
    var viewModel: PhoneViewModel
    var onCodeSent: (String, Bool) -> Void
    var onBack: (() -> Void)?

    /// Solo cambia al cruzar 10 dígitos; no se actualiza en cada tecla.
    @State private var phoneIsValid = false
    /// Capturado una vez para no leer `nationalDigits` en cada tecla (evita invalidar el body).
    @State private var initialDigits = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
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
            }

            Spacer().frame(height: 20)

            Text("Introduce tu número de celular")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)

            Spacer().frame(height: 10)

            Text("TE ENVIAREMOS UN CÓDIGO PARA CONFIRMARLO")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(subtitleBlack)

            Spacer().frame(height: 36)

            // El texto vive aquí: cada tecla no invalida checkboxes ni el resto del padre.
            PhoneNumberEntryField(
                initialDigits: initialDigits,
                isDisabled: viewModel.isLoading,
                onDigitsChange: { digits in
                    viewModel.onPhoneChange(digits)
                    let valid = digits.count == PhoneNationalInput.maxDigits
                    if valid != phoneIsValid {
                        phoneIsValid = valid
                    }
                }
            )

            if let err = viewModel.errorMessage {
                Spacer().frame(height: 12)
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }

            Spacer().frame(height: 32)

            PhoneConsentAndSendSection(
                phoneIsValid: phoneIsValid,
                isLoading: viewModel.isLoading,
                onSend: {
                    viewModel.sendCode { phone, userExists in
                        onCodeSent(phone, userExists)
                    }
                }
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .onAppear {
            initialDigits = viewModel.nationalDigits
            phoneIsValid = viewModel.nationalDigits.count == PhoneNationalInput.maxDigits
        }
    }
}

/// Campo de teléfono con estado local para que el teclado no redibuje toda la pantalla.
private struct PhoneNumberEntryField: View {
    let isDisabled: Bool
    let onDigitsChange: (String) -> Void

    @State private var phoneFieldText: String
    @FocusState private var isPhoneFieldFocused: Bool

    init(initialDigits: String, isDisabled: Bool, onDigitsChange: @escaping (String) -> Void) {
        self.isDisabled = isDisabled
        self.onDigitsChange = onDigitsChange
        let synced = String(initialDigits.filter(\.isNumber).prefix(PhoneNationalInput.maxDigits))
        _phoneFieldText = State(initialValue: synced)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 8) {
                Text("🇲🇽")
                Text("+52")
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            TextField(
                "",
                text: $phoneFieldText,
                prompt: Text("Tu número celular")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(phoneFieldPlaceholderColor)
            )
            .keyboardType(.numberPad)
            .textContentType(.telephoneNumber)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.black)
            .focused($isPhoneFieldFocused)
            .disabled(isDisabled)
            .onChange(of: phoneFieldText) { _, new in
                let capped = String(new.filter(\.isNumber).prefix(PhoneNationalInput.maxDigits))
                if capped != new {
                    phoneFieldText = capped
                    return
                }
                onDigitsChange(capped)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isPhoneFieldFocused = true
            }
        }
    }
}

/// Checkboxes + CTA aislados: toggling no invalida el TextField enfocado del padre.
private struct PhoneConsentAndSendSection: View {
    let phoneIsValid: Bool
    let isLoading: Bool
    let onSend: () -> Void

    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @Environment(\.openURL) private var openURL

    private var canSendCode: Bool {
        phoneIsValid && acceptedTerms && acceptedPrivacy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            legalRow(
                isOn: $acceptedTerms,
                prefix: "Acepto los ",
                linkTitle: "Términos y condiciones",
                url: termsURL
            )

            Spacer().frame(height: 12)

            legalRow(
                isOn: $acceptedPrivacy,
                prefix: "Acepto ",
                linkTitle: "Aviso de privacidad",
                url: privacyURL
            )

            Spacer().frame(height: 20)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(DobbyPureScale.onyx)
                    Spacer()
                }
            } else {
                Button(action: onSend) {
                    HStack(spacing: 10) {
                        Image(systemName: "message")
                        Text("Recibir código por SMS")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                    }
                    .foregroundStyle(canSendCode ? Color.white : DobbyPureScale.ash)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canSendCode ? DobbyPureScale.onyx : DobbyPureScale.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .stroke(canSendCode ? DobbyPureScale.onyx : DobbyPureScale.mist, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSendCode)
            }
        }
    }

    private func legalRow(
        isOn: Binding<Bool>,
        prefix: String,
        linkTitle: String,
        url: URL
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn.wrappedValue ? DobbyPureScale.onyx : Color.gray)
                    .contentTransition(.identity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                Text(prefix)
                    .font(.system(.subheadline))
                    .foregroundStyle(.black)
                Button {
                    openURL(url)
                } label: {
                    Text(linkTitle)
                        .font(.system(.subheadline))
                        .foregroundStyle(termsLinkBlue)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
