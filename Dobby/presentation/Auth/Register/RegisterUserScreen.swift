//
//  RegisterUserScreen.swift
//  Dobby
//

import SwiftUI

private let brandGreen = Color(red: 0x2E / 255, green: 0xCC / 255, blue: 0x71 / 255)
private let subtitleBlack = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
private let backSurface = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
private let fieldPlaceholderMuted = Color.black.opacity(0.35)
private let pageIndicatorActive = Color(red: 0x39 / 255, green: 0x67 / 255, blue: 1)

private let pageCount = 3

private enum RegistrationFocusedField: Hashable {
    case name
    case lastName
    case email
}

struct RegisterUserScreen: View {
    @Bindable var viewModel: RegisterUserViewModel
    var onComplete: () -> Void
    var onBack: (() -> Void)?

    @State private var page = 0
    @FocusState private var focusedField: RegistrationFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
                Button {
                    if page > 0 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            page -= 1
                        }
                        viewModel.clearError()
                    } else {
                        onBack()
                    }
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

            HStack {
                Spacer()
                ForEach(0 ..< pageCount, id: \.self) { index in
                    Circle()
                        .fill(page == index ? pageIndicatorActive : Color(red: 0xE0 / 255, green: 0xE0 / 255, blue: 0xE0 / 255))
                        .frame(width: 8, height: 8)
                        .padding(.horizontal, 4)
                }
                Spacer()
            }

            Spacer().frame(height: 24)

            Group {
                switch page {
                case 0:
                    registrationStep(title: "Ingresa tu nombre", subtitle: "LO USAREMOS PARA PERSONALIZAR TU EXPERIENCIA")
                case 1:
                    registrationStep(title: "Ingresa tus apellidos", subtitle: "COMO APARECEN EN TU IDENTIFICACIÓN")
                default:
                    registrationStep(title: "Ingresa tu correo electrónico", subtitle: "TE ENVIAREMOS NOTIFICACIONES Y CONFIRMACIONES")
                }
            }
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 36)

            Group {
                switch page {
                case 0:
                    registrationBasicField(
                        text: Binding(get: { viewModel.name }, set: { viewModel.onNameChange($0) }),
                        placeholder: "Nombre",
                        keyboardType: .default,
                        enabled: !viewModel.isLoading,
                        focus: .name
                    )
                case 1:
                    registrationBasicField(
                        text: Binding(get: { viewModel.lastName }, set: { viewModel.onLastNameChange($0) }),
                        placeholder: "Apellidos",
                        keyboardType: .default,
                        enabled: !viewModel.isLoading,
                        focus: .lastName
                    )
                default:
                    registrationBasicField(
                        text: Binding(get: { viewModel.email }, set: { viewModel.onEmailChange($0) }),
                        placeholder: "Correo electrónico",
                        keyboardType: .emailAddress,
                        enabled: !viewModel.isLoading,
                        textContentType: .emailAddress,
                        autocorrectionDisabled: true,
                        focus: .email
                    )
                }
            }

            if !viewModel.phone.isEmpty && page == 0 {
                Spacer().frame(height: 12)
                Text("Teléfono verificado: \(viewModel.phone)")
                    .font(.footnote)
                    .foregroundStyle(subtitleBlack)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let err = viewModel.errorMessage {
                Spacer().frame(height: 12)
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Spacer().frame(height: 24)

            if viewModel.isLoading && page == pageCount - 1 {
                HStack {
                    Spacer()
                    ProgressView().tint(brandGreen)
                    Spacer()
                }
            } else {
                Button {
                    if page < pageCount - 1 {
                        if viewModel.tryAdvanceFromStep(page) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                page += 1
                            }
                        }
                    } else {
                        viewModel.submit(onSuccess: onComplete)
                    }
                } label: {
                    Text(page == pageCount - 1 ? "Crear cuenta" : "Siguiente")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(brandGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .onAppear {
            scheduleFieldFocus(delay: 0.06)
        }
        .onChange(of: page) { _, _ in
            // Tras la animación del paso, el TextField nuevo recibe foco y el teclado sube.
            scheduleFieldFocus(delay: 0.14)
        }
    }

    private func fieldForPage(_ p: Int) -> RegistrationFocusedField {
        switch p {
        case 0: return .name
        case 1: return .lastName
        default: return .email
        }
    }

    private func scheduleFieldFocus(delay: TimeInterval) {
        let field = fieldForPage(page)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focusedField = field
        }
    }

    private func registrationStep(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(subtitleBlack)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func registrationBasicField(
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType,
        enabled: Bool,
        textContentType: UITextContentType? = nil,
        autocorrectionDisabled: Bool = false,
        focus: RegistrationFocusedField
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(fieldPlaceholderMuted)
        )
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
        .autocorrectionDisabled(autocorrectionDisabled)
        .textContentType(textContentType)
        .focused($focusedField, equals: focus)
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}
