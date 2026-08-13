//
//  ServiceBarcodeScanner.swift
//  Dobby
//
//  Camera barcode scan for service account numbers (VisionKit).
//

import AVFoundation
import SwiftUI
import VisionKit

enum ServiceBarcodeDigits {
    static func extract(from raw: String) -> String {
        raw.filter(\.isNumber)
    }
}

struct ServiceBarcodeScannerSheet: View {
    let onDigits: (String) -> Void
    let onDismiss: () -> Void

    @State private var unavailableMessage: String?
    @State private var cameraReady = false

    var body: some View {
        NavigationStack {
            Group {
                if let unavailableMessage {
                    ContentUnavailableView(
                        "Escáner no disponible",
                        systemImage: "barcode.viewfinder",
                        description: Text(unavailableMessage)
                    )
                } else if cameraReady,
                          DataScannerViewController.isSupported,
                          DataScannerViewController.isAvailable {
                    ServiceBarcodeScannerRepresentable(
                        onDigits: { digits in
                            onDigits(digits)
                            onDismiss()
                        },
                        onFail: { message in
                            unavailableMessage = message
                        }
                    )
                    .ignoresSafeArea()
                } else if !cameraReady && unavailableMessage == nil {
                    ProgressView("Preparando cámara…")
                } else {
                    ContentUnavailableView(
                        "Escáner no disponible",
                        systemImage: "barcode.viewfinder",
                        description: Text("Este dispositivo no puede escanear códigos de barras. Escribe el número manualmente.")
                    )
                }
            }
            .navigationTitle("Escanear recibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { onDismiss() }
                }
            }
            .task {
                await prepareCamera()
            }
        }
    }

    @MainActor
    private func prepareCamera() async {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            unavailableMessage = "Este dispositivo no puede escanear códigos de barras. Escribe el número manualmente."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraReady = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                cameraReady = true
            } else {
                unavailableMessage = "Activa el permiso de cámara en Ajustes para escanear el recibo."
            }
        default:
            unavailableMessage = "Activa el permiso de cámara en Ajustes para escanear el recibo."
        }
    }
}

private struct ServiceBarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onDigits: (String) -> Void
    let onFail: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDigits: onDigits, onFail: onFail)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        DispatchQueue.main.async {
            do {
                try scanner.startScanning()
            } catch {
                context.coordinator.onFail("No se pudo iniciar la cámara. Revisa el permiso de cámara en Ajustes.")
            }
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onDigits: (String) -> Void
        let onFail: (String) -> Void
        weak var scanner: DataScannerViewController?
        private var didEmit = false

        init(onDigits: @escaping (String) -> Void, onFail: @escaping (String) -> Void) {
            self.onDigits = onDigits
            self.onFail = onFail
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didEmit else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item else { continue }
                let raw = barcode.payloadStringValue ?? ""
                let digits = ServiceBarcodeDigits.extract(from: raw)
                guard !digits.isEmpty else { continue }
                didEmit = true
                dataScanner.stopScanning()
                onDigits(digits)
                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            switch error {
            case .cameraRestricted, .unsupported:
                onFail("La cámara no está disponible en este dispositivo.")
            @unknown default:
                onFail("No se pudo usar el escáner. Escribe el número manualmente.")
            }
        }
    }
}
