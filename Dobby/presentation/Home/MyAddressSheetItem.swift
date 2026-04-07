//
//  MyAddressSheetItem.swift
//  Dobby
//
//  Parity with Android `MyAddressSheetItem` in `AddressScreen.kt`.
//

import SwiftUI

private enum MyAddressSheetPalette {
    /// ~#5E4B8B
    static let labelPurple = Color(red: 94 / 255, green: 75 / 255, blue: 139 / 255)
    /// ~#EBE7F2
    static let cardFill = Color(red: 235 / 255, green: 231 / 255, blue: 242 / 255)
}

struct MyAddressSheetItem: View {
    let address: UserAddress
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 4) {
                Text(address.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MyAddressSheetPalette.labelPurple)
                Text(address.address.addressWithColonyOnly())
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(MyAddressSheetPalette.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
