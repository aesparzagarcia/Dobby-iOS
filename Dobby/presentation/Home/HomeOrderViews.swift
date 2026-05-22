//
//  HomeOrderViews.swift
//  Dobby
//
//  Checkout loading + home order tracking (parity with Android `OrderTrackingSection`).
//

import SwiftUI

private enum OrderUIPalette {
    /// App primary blue (#3967FF), parity with Android `Color.kt` / `MaterialTheme.colorScheme.primary`.
    static let primary = Color(red: 0x39 / 255, green: 0x67 / 255, blue: 0xFF / 255)
    static let headerTitle = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
    static let currentLabel = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
    static let inactiveBorder = Color(red: 0.82, green: 0.82, blue: 0.84)
    static let inactiveIcon = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let inactiveLabel = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let currentHalo = primary.opacity(0.22)
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

private struct TrackingStage {
    let label: String
    let systemImage: String
}

private let trackingStages: [TrackingStage] = [
    TrackingStage(label: "Pendiente", systemImage: "checkmark"),
    TrackingStage(label: "Confirmado", systemImage: "bag.fill"),
    TrackingStage(label: "En preparación", systemImage: "shippingbox.fill"),
    TrackingStage(label: "Listo para recoger", systemImage: "storefront.fill"),
    TrackingStage(label: "Asignado", systemImage: "person.fill"),
    TrackingStage(label: "En camino", systemImage: "scooter"),
    TrackingStage(label: "Entregado", systemImage: "checkmark"),
]

private let trackingStageIconSlotSize: CGFloat = 48
private let trackingStageCircleSize: CGFloat = 40

private enum TrackingConnectorStyle {
    case solidPurple
    case dashedPurple
    case dashedGrey
    case solidGrey
}

struct OrderTrackingSectionView: View {
    let activeOrder: ActiveOrder
    var onViewDetails: () -> Void = {}
    var headerTitle: String = "Tu pedido"

    private let lastStep = 6

    var body: some View {
        let step = activeOrder.stepIndex.clamped(to: 0...lastStep)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(headerTitle)
                    .font(.body.weight(.bold))
                    .foregroundStyle(OrderUIPalette.headerTitle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onViewDetails) {
                    HStack(spacing: 2) {
                        Text("Ver detalles")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(OrderUIPalette.primary)
            }
            .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(trackingStages.enumerated()), id: \.offset) { index, stage in
                        if index > 0 {
                            trackingConnector(
                                style: connectorStyle(leftStageIndex: index - 1, currentStepIndex: step)
                            )
                            .frame(width: 14)
                            .padding(.top, (trackingStageIconSlotSize - 3) / 2)
                        }

                        trackingStage(
                            label: stage.label,
                            systemImage: stage.systemImage,
                            isCompleted: index < step,
                            isCurrent: index == step
                        )
                        .frame(width: 72)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private func connectorStyle(leftStageIndex: Int, currentStepIndex: Int) -> TrackingConnectorStyle {
        if leftStageIndex < currentStepIndex - 1 { return .solidPurple }
        if leftStageIndex == currentStepIndex - 1 { return .dashedPurple }
        if leftStageIndex == currentStepIndex { return .dashedGrey }
        return .solidGrey
    }

    private func trackingStage(
        label: String,
        systemImage: String,
        isCompleted: Bool,
        isCurrent: Bool
    ) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if isCurrent {
                    Circle()
                        .fill(OrderUIPalette.currentHalo)
                        .frame(width: 52, height: 52)
                }

                Group {
                    if isCompleted {
                        Circle()
                            .fill(OrderUIPalette.primary)
                    } else if isCurrent {
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .strokeBorder(OrderUIPalette.primary, lineWidth: 2)
                            )
                    } else {
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .strokeBorder(OrderUIPalette.inactiveBorder, lineWidth: 1.5)
                            )
                    }
                }
                .frame(width: trackingStageCircleSize, height: trackingStageCircleSize)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isCompleted
                            ? Color.white
                            : (isCurrent ? OrderUIPalette.primary : OrderUIPalette.inactiveIcon)
                    )
            }
            .frame(width: trackingStageIconSlotSize, height: trackingStageIconSlotSize)

            Text(label)
                .font(.caption2)
                .fontWeight(isCurrent ? .bold : .regular)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    isCurrent
                        ? OrderUIPalette.currentLabel
                        : (isCompleted ? OrderUIPalette.primary : OrderUIPalette.inactiveLabel)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func trackingConnector(style: TrackingConnectorStyle) -> some View {
        let color: Color = {
            switch style {
            case .solidPurple, .dashedPurple: return OrderUIPalette.primary
            case .dashedGrey, .solidGrey: return OrderUIPalette.inactiveBorder
            }
        }()
        let dashed = style == .dashedPurple || style == .dashedGrey
        return GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    dash: dashed ? [6, 5] : []
                )
            )
        }
        .frame(height: 3)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
