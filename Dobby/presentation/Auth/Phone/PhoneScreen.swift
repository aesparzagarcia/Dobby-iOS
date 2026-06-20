//
//  PhoneScreen.swift
//  Dobby
//

import SwiftUI

private let subtitleBlack = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
private let backSurface = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
/// Placeholder del celular: más oscuro que el gris secundario del sistema.
private let phoneFieldPlaceholderColor = Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x55 / 255)

struct PhoneScreen: View {
    @Bindable var viewModel: PhoneViewModel
    var onCodeSent: (String, Bool) -> Void
    var onBack: (() -> Void)?

    @FocusState private var isPhoneFieldFocused: Bool
    /// Copia local del número: SwiftUI a veces no recorta el TextField si solo se acorta vía el modelo.
    @State private var phoneFieldText = ""

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
                    prompt: Text("384 1234 567")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(phoneFieldPlaceholderColor)
                )
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .focused($isPhoneFieldFocused)
                .disabled(viewModel.isLoading)
                .onChange(of: phoneFieldText) { _, new in
                    let capped = String(new.filter(\.isNumber).prefix(PhoneNationalInput.maxDigits))
                    if capped != new {
                        phoneFieldText = capped
                    }
                    viewModel.onPhoneChange(capped)
                }
            }

            if let err = viewModel.errorMessage {
                Spacer().frame(height: 12)
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }

            Spacer().frame(height: 32)

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(DobbyPureScale.onyx)
                    Spacer()
                }
            } else {
                Button {
                    viewModel.sendCode { phone, userExists in
                        onCodeSent(phone, userExists)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "message")
                        Text("Recibir código por SMS")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DobbyPureScale.onyx)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .stroke(DobbyPureScale.onyx, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .onAppear {
            let synced = String(viewModel.nationalDigits.filter(\.isNumber).prefix(PhoneNationalInput.maxDigits))
            phoneFieldText = synced
            if synced != viewModel.nationalDigits {
                viewModel.onPhoneChange(synced)
            }
            // Un ciclo después del layout para que el teclado aparezca al entrar a la pantalla.
            DispatchQueue.main.async {
                isPhoneFieldFocused = true
            }
        }
    }
}
