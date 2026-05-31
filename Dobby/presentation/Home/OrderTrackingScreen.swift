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
    static let primary = DobbyBrandColor.primary
    static let titleDark = DobbyBrandColor.dark
    static let statusBackground = DobbyBrandColor.primaryLightBackground
    static let statusSubtitle = Color(red: 0.42, green: 0.36, blue: 0.54)
    static let muted = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let totalBarBackground = DobbyBrandColor.light
    static let iconTileBackground = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let checkBadgeBackground = DobbyBrandColor.primary.opacity(0.18)
    /// Brand green aligned with Android OrderTrackingScreen / PhoneScreen (#2ECC71).
    static let brandGreen = Color(red: 46 / 255, green: 204 / 255, blue: 113 / 255)
}

/// Map camera parity with Android `MAP_BOUNDS_EXPANSION_FACTOR` / `DEFAULT_ZOOM`.
private enum OrderTrackingMapCamera {
    static let boundsExpansionFactor = 1.35
    static let minCoordinateSpan = 0.0035
    /// Single-marker span (~zoom 14.25 on Google Maps).
    static let singleMarkerSpan = 0.022
}

/// CTA parity with Android OrderTrackingScreen (18dp radius, 20sp, 15dp vertical padding).
private enum OrderTrackingDetailsCTA {
    static let cornerRadius: CGFloat = 18
    static let fontSize: CGFloat = 20
    static let verticalPadding: CGFloat = 15
    static let horizontalPadding: CGFloat = 20
    static let outerHorizontalPadding: CGFloat = 16
    static let outerBottomPadding: CGFloat = 32
}

/// Custom bottom sheet height (not system `presentationDetents`).
private enum OrderTrackingSheetMetrics {
    /// Map strip visible above the sheet while tracking in progress.
    static let expandedHeightFraction: CGFloat = 0.82
    /// Delivered / full-detail mode: leave room for floating header + status bar.
    static let fullScreenTopReserve: CGFloat = 100
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
    @State private var isScreenVisible = false
    /// When `true`, the order panel is shown and the map does not accept pan/zoom (per UX request).
    @State private var isOrderDetailSheetVisible = true
    /// Vertical drag on the sheet header (pull down to dismiss).
    @State private var sheetDragOffset: CGFloat = 0
    private let locationManager = CLLocationManager()

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack(alignment: .top) {
            Group {
                if let tracking = viewModel.tracking {
                    mapWithSheet(tracking: tracking)
                        .ignoresSafeArea(edges: SwiftUI.Edge.Set.bottom)
                } else if viewModel.isLoading {
                    ProgressView("Cargando…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            FloatingScreenHeader(
                title: "Seguimiento del pedido",
                onBack: onBack
            )
            .safeAreaPadding(.top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isScreenVisible = true
            locationManager.requestWhenInUseAuthorization()
            viewModel.onAppear()
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
            isScreenVisible = false
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.tracking?.id) { _, _ in
            guard isScreenVisible else { return }
            hasFittedCamera = false
            fitMapCamera()
        }
        .onChange(of: viewModel.tracking?.status) { _, _ in
            if viewModel.tracking?.isDelivered == true {
                isOrderDetailSheetVisible = true
            }
            guard isScreenVisible else { return }
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
        let shop = tracking.shopCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let customer = tracking.customerCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let destination = tracking.routeDestinationCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let destinationLabel = tracking.isAssignedToCourier ? "Restaurante" : "Entrega"
        let courier = coordinate(lat: tracking.deliveryMan?.lat, lng: tracking.deliveryMan?.lng)
        let route = viewModel.routePoints
        let usingStraightLineRoute = viewModel.usingStraightLineRoute
        let showsBothMarkers = tracking.showsRestaurantAndCustomerOnMap

        Map(
            position: $mapPosition,
            interactionModes: (!compact && isOrderDetailSheetVisible) ? MapInteractionModes() : .all
        ) {
            UserAnnotation()
            if showsBothMarkers, let c = shop {
                Annotation("Restaurante", coordinate: c) {
                    Image("IcShop")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if showsBothMarkers, let c = customer {
                Annotation("Entrega", coordinate: c) {
                    Image("IcHouse")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if !showsBothMarkers, let c = destination {
                Annotation(destinationLabel, coordinate: c) {
                    if tracking.isAssignedToCourier {
                        Image("IcShop")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    } else {
                        Image("IcHouse")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    }
                }
            }
            if let c = courier {
                Annotation("Repartidor", coordinate: c) {
                    Image("IcDelivery")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if route.count >= 2 {
                MapPolyline(coordinates: route)
                    .stroke(OrderTrackingPalette.primary, lineWidth: 4)
            }
        }
        .id(viewModel.orderId)
        .mapStyle(.standard)
        .mapControls {
            if compact || !isOrderDetailSheetVisible {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .overlay(alignment: .top) {
            if usingStraightLineRoute, destination != nil, courier != nil {
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
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up")
                        Text("Ver detalles del pedido")
                    }
                    .font(.system(size: OrderTrackingDetailsCTA.fontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OrderTrackingDetailsCTA.verticalPadding)
                    .padding(.horizontal, OrderTrackingDetailsCTA.horizontalPadding)
                }
                .buttonStyle(.plain)
                .background(
                    OrderTrackingPalette.brandGreen,
                    in: RoundedRectangle(
                        cornerRadius: OrderTrackingDetailsCTA.cornerRadius,
                        style: .continuous
                    )
                )
                .padding(.horizontal, OrderTrackingDetailsCTA.outerHorizontalPadding)
                .padding(.bottom, OrderTrackingDetailsCTA.outerBottomPadding)
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
        guard isScreenVisible, let t = viewModel.tracking, !hasFittedCamera else { return }
        let fitCoords: [CLLocationCoordinate2D] = t.mapCameraFitCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        guard !fitCoords.isEmpty else { return }

        if fitCoords.count >= 2 {
            let minLat = fitCoords.map(\.latitude).min()!
            let maxLat = fitCoords.map(\.latitude).max()!
            let minLon = fitCoords.map(\.longitude).min()!
            let maxLon = fitCoords.map(\.longitude).max()!
            let latSpanRaw = maxLat - minLat
            let lonSpanRaw = maxLon - minLon
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let factor = OrderTrackingMapCamera.boundsExpansionFactor
            let span = MKCoordinateSpan(
                latitudeDelta: max(latSpanRaw * factor, OrderTrackingMapCamera.minCoordinateSpan),
                longitudeDelta: max(lonSpanRaw * factor, OrderTrackingMapCamera.minCoordinateSpan)
            )
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        } else {
            let single = OrderTrackingMapCamera.singleMarkerSpan
            mapPosition = .region(
                MKCoordinateRegion(
                    center: fitCoords[0],
                    span: MKCoordinateSpan(latitudeDelta: single, longitudeDelta: single)
                )
            )
        }
        hasFittedCamera = true
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
        let screenHeight = UIScreen.main.bounds.height
        let maxSheetHeight: CGFloat = {
            if fullScreen {
                return screenHeight - OrderTrackingSheetMetrics.fullScreenTopReserve
            }
            return min(
                screenHeight * OrderTrackingSheetMetrics.expandedHeightFraction,
                screenHeight - 72
            )
        }()
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

        let sheetBody = orderBottomSheetBody(
            tracking: tracking,
            fullScreen: fullScreen,
            bottomInset: bottomInset,
            dragReveal: dragReveal
        )
        let needsScroll = fullScreen
            || tracking.isDelivered
            || tracking.items.count > 4
            || tracking.hasPendingRatings

        return Group {
            if needsScroll {
                ScrollView {
                    sheetBody
                }
                .contentMargins(.init(), for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity, maxHeight: maxSheetHeight, alignment: .top)
            } else {
                sheetBody
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(sheetShape)
        .shadow(color: .black.opacity(0.1), radius: 16, y: -2)
    }

    private func orderBottomSheetBody<G: Gesture>(
        tracking: OrderTrackingDetail,
        fullScreen: Bool,
        bottomInset: CGFloat,
        dragReveal: G
    ) -> some View {
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

            VStack(alignment: .leading, spacing: 14) {
                Text("Tu pedido")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OrderTrackingPalette.titleDark)
                    .padding(.top, 6)

                orderTrackingStatusCard(tracking: tracking)

                if let shop = tracking.shopName {
                    orderTrackingShopRow(
                        shopName: shop,
                        shopAddress: tracking.shopAddress ?? tracking.deliveryAddress
                    )
                }

                Text("PRODUCTOS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OrderTrackingPalette.muted)
                    .kerning(0.6)
                    .padding(.top, 4)

                ForEach(tracking.items, id: \.productId) { item in
                    orderTrackingProductRow(item: item)
                }

                let productsSubtotal = tracking.productsSubtotal > 0
                    ? tracking.productsSubtotal
                    : tracking.items.reduce(0) { $0 + $1.price * Double($1.quantity) }
                orderTrackingPricingSection(
                    productsSubtotal: productsSubtotal,
                    deliveryFee: tracking.deliveryFee,
                    total: tracking.total
                )

                orderTrackingCourierFooter(tracking: tracking)

                if tracking.isDelivered {
                    deliveredRatingsSection(tracking: tracking)
                } else if tracking.canRateDelivery {
                    ratingSection(tracking: tracking)
                }
                finishSection(tracking: tracking)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, max(bottomInset, 12))
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func orderTrackingStatusCard(tracking: OrderTrackingDetail) -> some View {
        HStack(alignment: .center, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                Image(systemName: orderTrackingStatusIcon(tracking.status))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OrderTrackingPalette.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(orderTrackingStatusTitle(tracking))
                    .font(.body.weight(.bold))
                    .foregroundStyle(OrderTrackingPalette.titleDark)
                    .lineLimit(2)
                Text(orderTrackingStatusSubtitle(tracking))
                    .font(.subheadline)
                    .foregroundStyle(OrderTrackingPalette.statusSubtitle)
                    .lineLimit(3)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsOrderTrackingStatusCheck(tracking.status) {
                ZStack {
                    Circle()
                        .fill(OrderTrackingPalette.checkBadgeBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OrderTrackingPalette.primary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(OrderTrackingPalette.statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func orderTrackingShopRow(shopName: String, shopAddress: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(OrderTrackingPalette.iconTileBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OrderTrackingPalette.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Tienda: \(shopName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrderTrackingPalette.titleDark)
                if let shopAddress, !shopAddress.isEmpty {
                    Text(shopAddress)
                        .font(.footnote)
                        .foregroundStyle(OrderTrackingPalette.muted)
                        .lineLimit(3)
                }
            }
        }
    }

    private func orderTrackingProductRow(item: OrderTrackingLineItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
                    .background(Color.white)
                    .frame(width: 52, height: 52)
                if let urlStr = item.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(OrderTrackingPalette.muted)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(OrderTrackingPalette.muted)
                }
            }
            Text("\(item.productName) ×\(item.quantity)")
                .font(.subheadline)
                .foregroundStyle(OrderTrackingPalette.titleDark)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "$%.2f", item.price * Double(item.quantity)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OrderTrackingPalette.titleDark)
        }
    }

    private func orderTrackingPricingSection(
        productsSubtotal: Double,
        deliveryFee: Double,
        total: Double
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Subtotal productos")
                    .font(.subheadline)
                    .foregroundStyle(OrderTrackingPalette.muted)
                Spacer()
                Text(String(format: "$%.2f", productsSubtotal))
                    .font(.subheadline)
                    .foregroundStyle(OrderTrackingPalette.muted)
            }
            if deliveryFee > 0 {
                HStack {
                    Text("Envío")
                        .font(.subheadline)
                        .foregroundStyle(OrderTrackingPalette.muted)
                    Spacer()
                    Text(String(format: "$%.2f", deliveryFee))
                        .font(.subheadline)
                        .foregroundStyle(OrderTrackingPalette.muted)
                }
            }
            HStack {
                Text("Total")
                    .font(.body.weight(.bold))
                    .foregroundStyle(OrderTrackingPalette.primary)
                Spacer()
                Text(String(format: "$%.2f", total))
                    .font(.body.weight(.bold))
                    .foregroundStyle(OrderTrackingPalette.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(OrderTrackingPalette.totalBarBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func orderTrackingCourierFooter(tracking: OrderTrackingDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OrderTrackingDashedDivider()
            if let dm = tracking.deliveryMan {
                courierAssignedCard(dm: dm)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OrderTrackingPalette.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aún no se ha asignado un repartidor.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OrderTrackingPalette.titleDark)
                        Text("Te notificaremos cuando tu pedido esté en camino.")
                            .font(.footnote)
                            .foregroundStyle(OrderTrackingPalette.muted)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func courierAssignedCard(dm: OrderTrackingCourier) -> some View {
        if let phone = dm.celphone, !phone.isEmpty, let url = telDialURL(phone) {
            Link(destination: url) {
                courierAssignedRow(dm: dm)
            }
        } else {
            courierAssignedRow(dm: dm)
        }
    }

    private func courierAssignedRow(dm: OrderTrackingCourier) -> some View {
        HStack(spacing: 12) {
            courierAvatar(dm: dm)
            VStack(alignment: .leading, spacing: 2) {
                Text("Repartidor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OrderTrackingPalette.primary)
                Text(dm.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrderTrackingPalette.titleDark)
            }
            Spacer()
            if dm.celphone != nil {
                Image(systemName: "phone.fill")
                    .foregroundStyle(OrderTrackingPalette.primary)
            }
        }
        .padding(12)
        .background(OrderTrackingPalette.iconTileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 4)
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

private struct OrderTrackingDashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(Color(.separator))
        }
        .frame(height: 1)
    }
}

private func orderTrackingStatusTitle(_ tracking: OrderTrackingDetail) -> String {
    if tracking.courierArrivedAtCustomer, tracking.status.uppercased() == "ON_DELIVERY" {
        let name = tracking.deliveryMan?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return "\(name) está afuera" }
        return "Repartidor afuera"
    }
    return orderStatusLabel(tracking.status)
}

private func orderTrackingStatusSubtitle(_ tracking: OrderTrackingDetail) -> String {
    if tracking.courierArrivedAtCustomer, tracking.status.uppercased() == "ON_DELIVERY" {
        return "Tu pedido te está esperando en la puerta"
    }
    switch tracking.status.uppercased() {
    case "PENDING":
        return "Esperando confirmación de la tienda"
    case "CONFIRMED":
        return "Gracias por tu compra"
    case "PREPARING":
        if let mins = tracking.estimatedPreparationMinutes {
            return "Tiempo estimado de preparación: \(mins) min"
        }
        return "Tu pedido se está preparando"
    case "READY_FOR_PICKUP":
        return "Listo para que el repartidor lo recoja"
    case "ASSIGNED":
        if let mins = tracking.estimatedDeliveryMinutes {
            return "Llegada estimada al recoger: ~\(mins) min"
        }
        return "Un repartidor irá por tu pedido pronto"
    case "ON_DELIVERY":
        if let mins = tracking.estimatedDeliveryMinutes {
            return "Llegada estimada: ~\(mins) min"
        }
        return "Tu pedido va en camino a tu domicilio"
    case "DELIVERED":
        return "¡Buen provecho!"
    case "CANCELLED":
        return "Este pedido fue cancelado"
    default:
        return ""
    }
}

private func orderTrackingStatusIcon(_ status: String) -> String {
    switch status.uppercased() {
    case "PREPARING", "READY_FOR_PICKUP":
        return "shippingbox.fill"
    default:
        return "bag.fill"
    }
}

private func showsOrderTrackingStatusCheck(_ status: String) -> Bool {
    !["PENDING", "CANCELLED"].contains(status.uppercased())
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
