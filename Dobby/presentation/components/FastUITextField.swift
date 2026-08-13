//
//  FastUITextField.swift
//  Dobby
//
//  UIKit-backed field: text lives in UITextField only (no SwiftUI @Binding on each key),
//  which avoids keyboard / typing jank under Observable NavigationStack parents.
//

import SwiftUI
import UIKit

struct FastUITextField: UIViewRepresentable {
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label
    var placeholderColor: UIColor = .placeholderText
    /// External write (e.g. barcode). Compared by identity; apply only when it changes.
    var externalText: String? = nil
    var onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.font = font
        field.textColor = textColor
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.clearButtonMode = .whileEditing
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        context.coordinator.onTextChange = onTextChange
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.onTextChange = onTextChange
        if uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        // Only push text from outside (barcode). Never rewrite while the user is typing.
        if let externalText,
           externalText != context.coordinator.lastExternalText {
            context.coordinator.lastExternalText = externalText
            if uiView.text != externalText {
                uiView.text = externalText
                onTextChange(externalText)
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onTextChange: (String) -> Void
        var lastExternalText: String?

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        @objc func editingChanged(_ field: UITextField) {
            onTextChange(field.text ?? "")
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
