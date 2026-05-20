//
//  OrderTrackingScreen.swift
//  Dobby
//
//  Parity with Android `OrderTrackingScreen`: map + bottom sheet with order details.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

private enum OrderTrackingPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    /// Light fill for status card (reference: soft purple panel).
    static let statusBackground = Color(red: 0.45, green: 0.35, blue: 0.75).opacity(0.14)
}

struct OrderTrackingScreen: View {
    @State private var viewModel: OrderTrackingViewModel
    let onBack: () -> Void
    let onFinish: () -> Void

    init(
        orderId: String,
        orderRepository: OrderRepository,
        directionsRepository: DirectionsRepository,
        http: DobbyHTTPClient,
        onBack: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: OrderTrackingViewModel(
                orderId: orderId,
                orderRepository: orderRepository,
                directionsRepository: directionsRepository,
                http: http
            )
        )
        self.onBack = onBack
        self.onFinish = onFinish
    }

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasFittedCamera = false
    /// When `true`, the order panel is shown and the map does not accept pan/zoom (per UX request).
    @State private var isOrderDetailSheetVisible = true
    /// Vertical drag on the sheet header (pull down to dismiss).
    @State private var sheetDragOffset: CGFloat = 0
    private let locationManager = CLLocationManager()

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isLoading {
                ProgressView("Cargando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = viewModel.errorMessage, viewModel.tracking == nil {
                Text(err)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let tracking = viewModel.tracking {
                mapWithSheet(tracking: tracking)
                    .ignoresSafeArea(edges: SwiftUI.Edge.Set.bottom)
            }
        }
        .navigationTitle("Seguimiento del pedido")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Volver")
            }
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            viewModel.onAppear()
            if viewModel.tracking?.isDelivered == true {
                isOrderDetailSheetVisible = true
            }
        }
        .onChange(of: viewModel.tracking?.status) { _, _ in
            if viewModel.tracking?.isDelivered == true {
                isOrderDetailSheetVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DobbyOrderRealtime.orderChangedNotification)) { notification in
            if let changedId = notification.userInfo?["order_id"] as? String,
               changedId != viewModel.orderId { return }
            viewModel.loadTracking()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.tracking?.id) { _, _ in
            hasFittedCamera = false
            fitMapCamera()
        }
    }

    @ViewBuilder
    private func mapWithSheet(tracking: OrderTrackingDetail) -> some View {
        if tracking.isDelivered {
            deliveredLayout(tracking: tracking)
        } else {
            inProgressLayout(tracking: tracking)
        }
    }

    @ViewBuilder
    private func deliveredLayout(tracking: OrderTrackingDetail) -> some View {
        VStack(spacing: 0) {
            trackingMap(tracking: tracking, compact: true)
                .frame(height: 112)
            orderBottomSheet(tracking: tracking, fullScreen: true)
        }
        .ignoresSafeArea(edges: SwiftUI.Edge.Set.bottom)
        .onAppear { fitMapCamera() }
    }

    @ViewBuilder
    private func inProgressLayout(tracking: OrderTrackingDetail) -> some View {
        ZStack(alignment: Alignment.bottom) {
            trackingMap(tracking: tracking, compact: false)
            inProgressSheetOverlay(tracking: tracking)
        }
        .ignoresSafeArea(edges: SwiftUI.Edge.Set.bottom)
        .animation(.easeInOut(duration: 0.25), value: isOrderDetailSheetVisible)
        .onChange(of: isOrderDetailSheetVisible) { _, visible in
            if visible { sheetDragOffset = 0 }
        }
        .onAppear {
            fitMapCamera()
        }
    }

    @ViewBuilder
    private func trackingMap(tracking: OrderTrackingDetail, compact: Bool) -> some View {
        let delivery = coordinate(lat: tracking.lat, lng: tracking.lng)
        let courier = coordinate(lat: tracking.deliveryMan?.lat, lng: tracking.deliveryMan?.lng)
        let route = viewModel.routePoints
        let usingStraightLineRoute = viewModel.usingStraightLineRoute

        Map(
            position: $mapPosition,
            interactionModes: (!compact && isOrderDetailSheetVisible) ? MapInteractionModes() : .all
        ) {
            UserAnnotation()
            if let c = delivery {
                Annotation("Entrega", coordinate: c) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(OrderTrackingPalette.primary, in: Circle())
                }
            }
            if let c = courier {
                Annotation("Repartidor", coordinate: c) {
                    Image(systemName: "bicycle")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.orange, in: Circle())
                }
            }
            if route.count >= 2 {
                MapPolyline(coordinates: route)
                    .stroke(Color.blue, lineWidth: 4)
            }
        }
        .mapStyle(.standard)
        .mapControls {
            if compact || !isOrderDetailSheetVisible {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .overlay(alignment: .top) {
            if usingStraightLineRoute, delivery != nil, courier != nil {
                Text(
                    "La ruta por calles no está disponible (solo línea recta). " +
                    "Habilita Directions API y facturación en Google Cloud, y define DIRECTIONS_API_KEY " +
                    "con una clave apta para el servicio web (no solo restricción «aplicaciones iOS»)."
                )
                .font(.caption)
                .foregroundStyle(Color(.label))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemRed).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func inProgressSheetOverlay(tracking: OrderTrackingDetail) -> some View {
        ZStack(alignment: Alignment.bottom) {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(isOrderDetailSheetVisible)
                .onTapGesture {
                    guard isOrderDetailSheetVisible else { return }
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isOrderDetailSheetVisible = false
                    }
                }

            if isOrderDetailSheetVisible {
                orderBottomSheet(tracking: tracking, fullScreen: false)
                    .offset(y: sheetDragOffset)
                    .transition(.move(edge: SwiftUI.Edge.bottom).combined(with: .opacity))
            } else {
                Button {
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isOrderDetailSheetVisible = true
                    }
                } label: {
                    Label("Ver detalles del pedido", systemImage: "chevron.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(OrderTrackingPalette.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, orderTrackingBottomSafeInset() + 10)
                .transition(.move(edge: SwiftUI.Edge.bottom).combined(with: .opacity))
            }
        }
    }

    private func coordinate(lat: Double?, lng: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Fits delivery + courier once on first load. Does not run again on poll updates so manual zoom/pan is preserved.
    private func fitMapCamera() {
        guard let t = viewModel.tracking, !hasFittedCamera else { return }
        let delivery = coordinate(lat: t.lat, lng: t.lng)
        let courier = coordinate(lat: t.deliveryMan?.lat, lng: t.deliveryMan?.lng)

        if let a = delivery, let b = courier {
            let minLat = min(a.latitude, b.latitude)
            let maxLat = max(a.latitude, b.latitude)
            let minLon = min(a.longitude, b.longitude)
            let maxLon = max(a.longitude, b.longitude)
            let latSpanRaw = maxLat - minLat
            let lonSpanRaw = maxLon - minLon
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
            // ~8% padding around both points; lower floor → closer zoom when markers are near each other.
            let span = MKCoordinateSpan(
                latitudeDelta: max(latSpanRaw * 1.08, 0.0035),
                longitudeDelta: max(lonSpanRaw * 1.08, 0.0035)
            )
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
            hasFittedCamera = true
            return
        }
        if let c = delivery ?? courier {
            mapPosition = .region(
                MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014))
            )
            hasFittedCamera = true
        }
    }

    private func orderBottomSheet(tracking: OrderTrackingDetail, fullScreen: Bool) -> some View {
        let sheetShape = UnevenRoundedRectangle(
            topLeadingRadius: fullScreen ? 16 : 24,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: fullScreen ? 16 : 24,
            style: .continuous
        )
        let bottomInset = orderTrackingBottomSafeInset()
        let sheetHeight: CGFloat = fullScreen
            ? UIScreen.main.bounds.height - 112
            : UIScreen.main.bounds.height * 0.44 + bottomInset
        let dragReveal = DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !fullScreen, value.translation.height > 0 else { return }
                sheetDragOffset = value.translation.height
            }
            .onEnded { value in
                guard !fullScreen else { return }
                let dy = value.translation.height
                let flick = value.predictedEndTranslation.height
                let shouldDismiss = dy > 90 || flick > 160
                if shouldDismiss {
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) { isOrderDetailSheetVisible = false }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { sheetDragOffset = 0 }
                }
            }

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !fullScreen {
                    ZStack(alignment: .top) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(dragReveal)
                        Capsule()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tu pedido")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(OrderTrackingPalette.primary)
                        .padding(.top, 6)

                    statusRow(tracking: tracking)

                    if let shop = tracking.shopName {
                        Text("Tienda: \(shop)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    if let addr = tracking.deliveryAddress {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(OrderTrackingPalette.primary)
                            Text(addr)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }

                    Text("Productos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    ForEach(Array(tracking.items.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text("\(item.productName) ×\(item.quantity)")
                            Spacer()
                            Text(String(format: "$%.2f", item.price * Double(item.quantity)))
                        }
                        .font(.subheadline)
                    }

                    let productsSubtotal = tracking.productsSubtotal > 0
                        ? tracking.productsSubtotal
                        : tracking.items.reduce(0) { $0 + $1.price * Double($1.quantity) }
                    HStack {
                        Text("Subtotal productos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", productsSubtotal))
                            .font(.subheadline)
                    }
                    .padding(.top, 4)

                    if tracking.deliveryFee > 0 {
                        HStack {
                            Text("Envío")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "$%.2f", tracking.deliveryFee))
                                .font(.subheadline)
                        }
                    }

                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "$%.2f", tracking.total))
                            .font(.headline)
                    }
                    .padding(.top, 4)

                    courierSection(tracking: tracking)
                    if tracking.isDelivered {
                        deliveredRatingsSection(tracking: tracking)
                    } else if tracking.canRateDelivery {
                        ratingSection(tracking: tracking)
                    }
                    finishSection(tracking: tracking)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16 + bottomInset)
            }
            .frame(maxWidth: .infinity, minHeight: sheetHeight, alignment: .top)
        }
        .contentMargins(.init(), for: .scrollContent)
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: sheetHeight)
        .background(Color(.systemBackground))
        .clipShape(sheetShape)
        .shadow(color: .black.opacity(0.1), radius: 16, y: -2)
    }

    private func statusRow(tracking: OrderTrackingDetail) -> some View {
        let st = tracking.status.uppercased()
        let deliveryEta: String? = {
            guard st == "ON_DELIVERY" || st == "ASSIGNED",
                  let minutes = tracking.estimatedDeliveryMinutes else { return nil }
            return "Llegada ~\(minutes) min"
        }()
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .foregroundStyle(OrderTrackingPalette.primary)
                Text(orderTrackingStatusLabel(tracking))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let deliveryEta {
                    Text(deliveryEta)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OrderTrackingPalette.primary)
                } else if let prep = tracking.estimatedPreparationMinutes {
                    Text("Prep. estimada: \(prep) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OrderTrackingPalette.statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func courierSection(tracking: OrderTrackingDetail) -> some View {
        if let dm = tracking.deliveryMan {
            Text("Repartidor")
                .font(.headline)
                .foregroundStyle(OrderTrackingPalette.primary)

            if let phone = dm.celphone, !phone.isEmpty,
               let url = telDialURL(phone) {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        courierAvatar(dm: dm)
                        Text(dm.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "phone.fill")
                            .foregroundStyle(OrderTrackingPalette.primary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                HStack(spacing: 12) {
                    courierAvatar(dm: dm)
                    Text(dm.name)
                        .font(.body.weight(.medium))
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        } else {
            Text("Aún no se ha asignado un repartidor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func courierAvatar(dm: OrderTrackingCourier) -> some View {
        Group {
            if let urlStr = AppConfiguration.fullImageURL(dm.profilePhotoUrl), let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 48)
            }
        }
    }

    @ViewBuilder
    private func deliveredRatingsSection(tracking: OrderTrackingDetail) -> some View {
        Text("Valora tu experiencia")
            .font(.headline)
            .foregroundStyle(OrderTrackingPalette.primary)
            .padding(.top, 8)

        if tracking.canRateShop || tracking.shopRating != nil {
            starRatingBlock(
                title: "Restaurante",
                subtitle: tracking.shopName ?? "Tienda",
                existingRating: tracking.shopRating,
                canRate: tracking.canRateShop,
                onSelect: { viewModel.submitShopRating($0) }
            )
        }

        if tracking.deliveryMan != nil, tracking.canRateDelivery || tracking.deliveryRating != nil {
            starRatingBlock(
                title: "Repartidor",
                subtitle: tracking.deliveryMan?.name ?? "Repartidor",
                existingRating: tracking.deliveryRating,
                canRate: tracking.canRateDelivery,
                onSelect: { viewModel.submitDeliveryRating($0) }
            )
        }

        ForEach(tracking.items.filter { $0.canRate || $0.rating != nil }, id: \.productId) { item in
            starRatingBlock(
                title: "Producto",
                subtitle: "\(item.productName) ×\(item.quantity)",
                existingRating: item.rating,
                canRate: item.canRate,
                onSelect: { viewModel.submitProductRating(productId: item.productId, stars: $0) }
            )
        }

        if viewModel.rateSubmitting {
            Text("Enviando…")
                .font(.caption)
        }
        if let re = viewModel.rateError {
            Text(re)
                .font(.caption)
                .foregroundStyle(.red)
                .onTapGesture { viewModel.clearRateError() }
        }
    }

    @ViewBuilder
    private func starRatingBlock(
        title: String,
        subtitle: String,
        existingRating: Int?,
        canRate: Bool,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OrderTrackingPalette.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if canRate {
                HStack(spacing: 8) {
                    ForEach(1 ... 5, id: \.self) { s in
                        Button {
                            if !viewModel.rateSubmitting { onSelect(s) }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(s)")
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                        }
                        .disabled(viewModel.rateSubmitting)
                    }
                }
            } else if let r = existingRating {
                let stars = min(max(r, 1), 5)
                Text("Tu valoración: \(String(repeating: "⭐", count: stars))")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func ratingSection(tracking: OrderTrackingDetail) -> some View {
        if tracking.canRateDelivery {
            Text("¿Cómo fue el reparto?")
                .font(.headline)
                .foregroundStyle(OrderTrackingPalette.primary)
            Text("Tu valoración ayuda a otros usuarios.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(1 ... 5, id: \.self) { s in
                    Button {
                        if !viewModel.rateSubmitting { viewModel.submitDeliveryRating(s) }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(s)")
                            Image(systemName: "star.fill")
                                .font(.caption2)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.rateSubmitting)
                }
            }
            if viewModel.rateSubmitting {
                Text("Enviando…")
                    .font(.caption)
            }
            if let re = viewModel.rateError {
                Text(re)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .onTapGesture { viewModel.clearRateError() }
            }
        } else if let r = tracking.deliveryRating {
            let stars = min(max(r, 1), 5)
            Text("Tu valoración: \(String(repeating: "⭐", count: stars))")
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func finishSection(tracking: OrderTrackingDetail) -> some View {
        if shouldShowFinishButton(tracking: tracking) {
            Button {
                onFinish()
            } label: {
                Text("Finalizar")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(OrderTrackingPalette.primary)
            .padding(.top, 8)
        }
    }

    private func shouldShowFinishButton(tracking: OrderTrackingDetail) -> Bool {
        tracking.isDelivered && !tracking.hasPendingRatings
    }

    private func orderTrackingBottomSafeInset() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return 0 }
        return scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom ?? 0
    }
}

private func telDialURL(_ raw: String) -> URL? {
    let cleaned = raw.filter { $0.isNumber || $0 == "+" }
    guard !cleaned.isEmpty else { return nil }
    return URL(string: "tel:\(cleaned)")
}

private func orderTrackingStatusLabel(_ tracking: OrderTrackingDetail) -> String {
    if tracking.courierArrivedAtCustomer, tracking.status.uppercased() == "ON_DELIVERY" {
        let name = tracking.deliveryMan?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return "\(name) está afuera con tu pedido" }
        return "Repartidor afuera con tu pedido"
    }
    return orderStatusLabel(tracking.status)
}

private func orderStatusLabel(_ status: String) -> String {
    switch status.uppercased() {
    case "PENDING": return "Pendiente"
    case "CONFIRMED": return "Confirmado"
    case "PREPARING": return "En preparación"
    case "READY_FOR_PICKUP": return "Listo para recoger"
    case "ASSIGNED": return "Asignado a repartidor"
    case "ON_DELIVERY": return "En camino"
    case "DELIVERED": return "Entregado"
    case "CANCELLED": return "Cancelado"
    default: return status
    }
}
