//
//  HomeOrderViews.swift
//  Dobby
//
//  Checkout loading + home order tracking (parity with Android `OrderTrackingSection`).
//

import SwiftUI

private enum OrderUIPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
}

// MARK: - Place order loading

struct PlaceOrderLoadingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OrderUIPalette.primary.opacity(0.92),
                    Color(red: 0.35, green: 0.28, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.12 : 1.0)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: 10) {
                    Text("Creando tu pedido")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Esto puede tardar unos segundos. No cierres la app.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Order tracking (home)

private let trackingStageLabels = [
    "Pendiente",
    "Confirmado",
    "Preparando",
    "Listo",
    "Asignado",
    "En camino",
    "Entregado",
]

private let trackingStageIcons: [String] = [
    "clock.fill",
    "bag.fill",
    "shippingbox.fill",
    "car.fill",
    "person.fill",
    "bicycle",
    "checkmark.circle.fill",
]

struct OrderTrackingSectionView: View {
    let activeOrder: ActiveOrder
    var onViewDetails: () -> Void = {}

    private let lastStep = 6
    /// Step index for `ASSIGNED` — hide map entry until courier can appear on map.
    private let assignedStep = 4
    @State private var currentStepPulse = false

    var body: some View {
        let step = activeOrder.stepIndex.clamped(to: 0...lastStep)
        let showMapButton = step >= assignedStep

        VStack(alignment: .leading, spacing: 0) {
            Text("Tu pedido")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(trackingStageLabels.enumerated()), id: \.offset) { index, label in
                        trackingStage(
                            label: label,
                            systemImage: trackingStageIcons[index],
                            isCompleted: index < step,
                            isCurrent: index == step,
                            pulse: currentStepPulse
                        )
                        .frame(width: 68)

                        if index < trackingStageLabels.count - 1 {
                            trackingConnector(completed: index < step)
                                .frame(width: 16)
                                .padding(.horizontal, 2)
                        }
                    }
                }
            }

            if showMapButton {
                Button(action: onViewDetails) {
                    Text("Ver mapa y detalles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(OrderUIPalette.primary)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        .task {
            while !Task.isCancelled {
                currentStepPulse.toggle()
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }
    }

    private func trackingStage(
        label: String,
        systemImage: String,
        isCompleted: Bool,
        isCurrent: Bool,
        pulse: Bool
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isCompleted || isCurrent ? OrderUIPalette.primary : Color(.systemGray4))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isCurrent && pulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.45), value: pulse)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCompleted || isCurrent ? Color.white : Color.secondary.opacity(0.7))
            }

            Text(label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isCompleted || isCurrent ? OrderUIPalette.primary : Color.secondary.opacity(0.75))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private func trackingConnector(completed: Bool) -> some View {
        Rectangle()
            .fill(completed ? OrderUIPalette.primary : Color(.systemGray4))
            .frame(height: 3)
            .clipShape(Capsule())
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
