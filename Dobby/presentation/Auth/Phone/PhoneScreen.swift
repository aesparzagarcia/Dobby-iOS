//
//  PhoneScreen.swift
//  Dobby
//

import SwiftUI

private let brandGreen = Color(red: 0x2E / 255, green: 0xCC / 255, blue: 0x71 / 255)
private let subtitleBlack = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
private let backSurface = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
private let outlinedBorder = Color(red: 0xD9 / 255, green: 0xD9 / 255, blue: 0xD9 / 255)

struct PhoneScreen: View {
    @Bindable var viewModel: PhoneViewModel
    var onCodeSent: (String, Bool) -> Void
    var onBack: (() -> Void)?

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
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

                TextField("", text: Binding(
                    get: { viewModel.nationalDigits },
                    set: { viewModel.onPhoneChange($0) }
                ))
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .disabled(viewModel.isLoading)
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
                    ProgressView().tint(brandGreen)
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandGreen)

                Spacer().frame(height: 14)

                Button {
                    viewModel.sendCode { phone, userExists in
                        onCodeSent(phone, userExists)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Recibir código por WhatsApp")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.bordered)
                .tint(brandGreen)
                .overlay(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(outlinedBorder, lineWidth: 1)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}
