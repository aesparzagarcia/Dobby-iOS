//
//  RegisterUserScreen.swift
//  Dobby
//

import SwiftUI

struct RegisterUserScreen: View {
    @Bindable var viewModel: RegisterUserViewModel
    var onComplete: () -> Void
    var onBack: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let onBack {
                    HStack {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }

                Text("Completa tu perfil")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 8)

                Text("Añade tus datos para crear una cuenta")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                TextField("Nombre", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.onNameChange($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isLoading)
                .textInputAutocapitalization(.words)

                Spacer().frame(height: 16)

                TextField("Apellido", text: Binding(
                    get: { viewModel.lastName },
                    set: { viewModel.onLastNameChange($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isLoading)
                .textInputAutocapitalization(.words)

                Spacer().frame(height: 16)

                TextField("Número de teléfono", text: .constant(viewModel.phone))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Spacer().frame(height: 16)

                TextField("Correo electrónico", text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.onEmailChange($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .disabled(viewModel.isLoading)

                if let err = viewModel.errorMessage {
                    Spacer().frame(height: 8)
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer().frame(height: 24)

                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        viewModel.submit(onSuccess: onComplete)
                    } label: {
                        Text("Crear cuenta")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
