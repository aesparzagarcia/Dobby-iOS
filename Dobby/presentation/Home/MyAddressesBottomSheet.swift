//
//  MyAddressesBottomSheet.swift
//  Dobby
//
//  Content shown inside the modal sheet (parity with Android `ModalBottomSheet` block in `AddressScreen.kt`).
//

import SwiftUI

private enum MyAddressesSheetPalette {
    /// ~#F3F0F7
    static let sheetBackground = Color(red: 243 / 255, green: 240 / 255, blue: 247 / 255)
}

struct MyAddressesBottomSheet: View {
    let uiState: AddressUiState
    let onSelect: (UserAddress) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mis direcciones")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 40)
                .padding(.bottom, 16)

            if uiState.myAddresses.isEmpty {
                Text("No hay direcciones guardadas")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(uiState.myAddresses) { address in
                            MyAddressSheetItem(address: address) {
                                onSelect(address)
                            }
                        }
                    }
                }
            }

            if let err = uiState.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MyAddressesSheetPalette.sheetBackground)
    }
}
