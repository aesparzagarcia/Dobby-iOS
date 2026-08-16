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
    static let detailsButtonBackground = Color.black
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
    /// Map strip visible above the sheet while tracking in progress / delivered.
    static let expandedHeightFraction: CGFloat = 0.68
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
                title: viewModel.tracking?.isCarWash == true
                    ? "Seguimiento del servicio"
                    : "Seguimiento del pedido",
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
        ZStack(alignment: Alignment.bottom) {
            trackingMap(tracking: tracking, compact: false)
            orderBottomSheet(tracking: tracking, fullScreen: false)
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
        let destinationLabel = tracking.isAssignedToCourier
            ? (tracking.isCarWash ? "Autolavado" : "Restaurante")
            : "Entrega"
        let shop = tracking.shopCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let customer = tracking.customerCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let destination = tracking.routeDestinationCoordinate.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }
        let courierFromApi = coordinate(lat: tracking.deliveryMan?.lat, lng: tracking.deliveryMan?.lng)
        let courierFallback: CLLocationCoordinate2D? = {
            guard tracking.isCarWash else { return nil }
            if tracking.isPickedUp, let customer { return customer }
            if tracking.isOnDelivery || tracking.isAssignedToCourier || tracking.isOutForPickup,
               let shop {
                return shop
            }
            return nil
        }()
        let courier = courierFromApi ?? courierFallback
        let showsBothMarkers = tracking.showsRestaurantAndCustomerOnMap
        let showsPendingCustomer = tracking.showsPendingCustomerOnMap
        let shopMarkerImage = tracking.isCarWash ? "IcCarWash" : "IcShop"
        let showShopMarker: Bool = {
            guard let shop else { return false }
            if tracking.isCarWash {
                if let courier {
                    let far =
                        abs(shop.latitude - courier.latitude) > 1e-4 ||
                        abs(shop.longitude - courier.longitude) > 1e-4
                    return far || showsBothMarkers && !(
                        tracking.isOnDelivery
                            || tracking.isAssignedToCourier
                            || tracking.isOutForPickup
                            || tracking.isPickedUp
                    )
                }
                return true
            }
            return showsBothMarkers
        }()
        // Durante recolección no mostramos la casa; sí desde Recogido en adelante.
        let showCustomerMarker =
            (showsBothMarkers
                || (tracking.isCarWash
                    && (tracking.isOnDelivery || tracking.isAssignedToCourier || tracking.isPickedUp)))
            && !tracking.isOutForPickup
            && customer != nil
        let vehicleTitle = tracking.isCarWash ? "Tu vehículo" : "Repartidor"
        let vehicleImage = tracking.isCarWash ? "IcCar" : "IcDelivery"

        Map(
            position: $mapPosition,
            interactionModes: .all
        ) {
            UserAnnotation()
            if showShopMarker, let c = shop {
                Annotation(tracking.isCarWash ? "Autolavado" : "Restaurante", coordinate: c) {
                    Image(shopMarkerImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if showCustomerMarker, let c = customer {
                Annotation("Entrega", coordinate: c) {
                    Image("IcHouse")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if showsPendingCustomer, let c = customer, !showCustomerMarker {
                Annotation("Entrega", coordinate: c) {
                    Image("IcHouse")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            if !showsBothMarkers, !showsPendingCustomer, !tracking.isCarWash, let c = destination {
                Annotation(destinationLabel, coordinate: c) {
                    if tracking.isAssignedToCourier {
                        Image(shopMarkerImage)
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
                Annotation(vehicleTitle, coordinate: c) {
                    Image(vehicleImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
        }
        .id(viewModel.orderId)
        .mapStyle(.standard)
        .mapControls {
            if !compact {
                MapUserLocationButton()
                MapCompass()
            }
        }
    }

    @ViewBuilder
    private func inProgressSheetOverlay(tracking: OrderTrackingDetail) -> some View {
        // Solo el sheet ocupa hits; el área del mapa queda libre para pan/zoom (como DobbyShop).
        orderBottomSheet(tracking: tracking, fullScreen: false)
            .offset(y: isOrderDetailSheetVisible ? sheetDragOffset : 0)
            .animation(.easeInOut(duration: 0.25), value: isOrderDetailSheetVisible)
    }

    private func coordinate(lat: Double?, lng: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Fits delivery + courier once on first load. Falls back to user GPS when no order coordinates exist yet (e.g. PENDING).
    private func fitMapCamera() {
        guard isScreenVisible, let t = viewModel.tracking, !hasFittedCamera else { return }
        let fitCoords: [CLLocationCoordinate2D] = t.mapCameraFitCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
        }

        if !fitCoords.isEmpty {
            applyMapCamera(to: fitCoords)
            hasFittedCamera = true
            return
        }

        Task {
            guard let location = try? await OneShotLocationRequest().getLocation() else { return }
            await MainActor.run {
                guard isScreenVisible, !hasFittedCamera else { return }
                applyMapCamera(to: [location.coordinate])
                hasFittedCamera = true
            }
        }
    }

    private func applyMapCamera(to fitCoords: [CLLocationCoordinate2D]) {
        guard let first = fitCoords.first else { return }

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
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: single, longitudeDelta: single)
                )
            )
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
                guard !fullScreen else { return }
                sheetDragOffset = value.translation.height
            }
            .onEnded { value in
                guard !fullScreen else { return }
                let dy = value.translation.height
                let flick = value.predictedEndTranslation.height
                if dy > 48 || flick > 120 {
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) { isOrderDetailSheetVisible = false }
                } else if dy < -48 || flick < -120 {
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) { isOrderDetailSheetVisible = true }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { sheetDragOffset = 0 }
                }
            }

        let sheetBody = orderBottomSheetBody(
            tracking: tracking,
            fullScreen: fullScreen,
            bottomInset: bottomInset,
            dragReveal: dragReveal,
            collapsed: !fullScreen && !isOrderDetailSheetVisible
        )
        let needsScroll = isOrderDetailSheetVisible && (
            fullScreen
                || tracking.items.count > 4
                || tracking.hasPendingRatings
        )

        return Group {
            if needsScroll {
                ScrollView {
                    sheetBody
                }
                .contentMargins(.init(), for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity, maxHeight: maxSheetHeight, alignment: .top)
                // Evita que el ScrollView crezca hasta maxHeight dejando blanco vacío.
                .fixedSize(horizontal: false, vertical: true)
            } else {
                sheetBody
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(sheetShape)
        .shadow(color: .black.opacity(0.1), radius: 16, y: -2)
        // Sin scroll: altura = contenido para no tapar el mapa. Con scroll: respeta maxHeight.
        .fixedSize(horizontal: false, vertical: !fullScreen && !needsScroll)
    }

    private func orderBottomSheetBody<G: Gesture>(
        tracking: OrderTrackingDetail,
        fullScreen: Bool,
        bottomInset: CGFloat,
        dragReveal: G,
        collapsed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !fullScreen {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)

                    HStack(spacing: 4) {
                        Text(collapsed ? "Mostrar detalles" : "Ocultar detalles")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: collapsed ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    // Keep collapsed handle above the home indicator and a bit higher for reach.
                    .padding(.bottom, collapsed ? max(bottomInset, 12) + 20 : 0)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    sheetDragOffset = 0
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isOrderDetailSheetVisible.toggle()
                    }
                }
                .gesture(dragReveal)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }

            if !collapsed {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tracking.isCarWash ? "Tu servicio" : "Tu pedido")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OrderTrackingPalette.titleDark)
                    .padding(.top, 14)

                orderTrackingStatusCard(tracking: tracking)

                if tracking.courierArrivedAtCustomer,
                   (tracking.isOnDelivery || tracking.isOutForPickup),
                   let code = tracking.deliveryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !code.isEmpty {
                    orderTrackingDeliveryCodeCard(code: code, isPickupHandoff: tracking.isOutForPickup)
                }

                if let shop = tracking.shopName {
                    orderTrackingShopRow(
                        shopName: shop,
                        shopAddress: tracking.shopAddress ?? tracking.deliveryAddress,
                        isCarWash: tracking.isCarWash
                    )
                }

                Text(tracking.isCarWash ? "SERVICIOS" : "PRODUCTOS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OrderTrackingPalette.muted)
                    .kerning(0.6)
                    .padding(.top, 4)

                ForEach(tracking.items) { item in
                    orderTrackingProductRow(item: item)
                }

                let productsSubtotal = tracking.productsSubtotal > 0
                    ? tracking.productsSubtotal
                    : tracking.items.reduce(0) { $0 + $1.price * Double($1.quantity) }
                orderTrackingPricingSection(
                    productsSubtotal: productsSubtotal,
                    serviceFee: tracking.serviceFee,
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
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func orderTrackingDeliveryCodeCard(code: String, isPickupHandoff: Bool = false) -> some View {
        VStack(spacing: 10) {
            Text(isPickupHandoff ? "TU CÓDIGO DE RECOLECCIÓN" : "TU CÓDIGO DE ENTREGA")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OrderTrackingPalette.muted)
                .kerning(0.6)
            Text(code)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(OrderTrackingPalette.primary)
                .kerning(6)
            Text(
                isPickupHandoff
                    ? "Muéstralo al carwash para entregar tu carro."
                    : "Muéstralo al repartidor para confirmar la entrega."
            )
                .font(.subheadline)
                .foregroundStyle(OrderTrackingPalette.statusSubtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OrderTrackingPalette.statusBackground)
        )
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

    private func orderTrackingShopRow(shopName: String, shopAddress: String?, isCarWash: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(OrderTrackingPalette.iconTileBackground)
                    .frame(width: 44, height: 44)
                if isCarWash {
                    Image("IcCarWash")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OrderTrackingPalette.primary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isCarWash ? "Lavado: \(shopName)" : "Tienda: \(shopName)")
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
                LoadingRemoteImage(urlString: item.imageUrl) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(OrderTrackingPalette.muted)
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        serviceFee: Double,
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
            if serviceFee > 0 {
                HStack {
                    Text("Tarifa de servicio")
                        .font(.subheadline)
                        .foregroundStyle(OrderTrackingPalette.muted)
                    Spacer()
                    Text(String(format: "$%.2f", serviceFee))
                        .font(.subheadline)
                        .foregroundStyle(OrderTrackingPalette.muted)
                }
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
        if !tracking.isCarWash {
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
        LoadingRemoteImage(urlString: dm.profilePhotoUrl, resolveAgainstApiBase: true) {
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func deliveredRatingsSection(tracking: OrderTrackingDetail) -> some View {
        Text("Valora tu experiencia")
            .font(.headline)
            .foregroundStyle(OrderTrackingPalette.primary)
            .padding(.top, 8)

        if tracking.canRateShop || tracking.shopRating != nil {
            starRatingBlock(
                title: tracking.isCarWash ? "Lavado" : "Restaurante",
                subtitle: tracking.shopName ?? (tracking.isCarWash ? "Lavado" : "Tienda"),
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

        ForEach(tracking.items.filter { $0.canRate || $0.rating != nil }) { item in
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
    if tracking.courierArrivedAtCustomer,
       tracking.isOnDelivery || tracking.isOutForPickup {
        if tracking.isCarWash {
            return tracking.isOutForPickup ? "El carwash llegó" : "Tu coche está afuera"
        }
        let name = tracking.deliveryMan?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return "\(name) está afuera" }
        return "Repartidor afuera"
    }
    return orderStatusLabel(
        tracking.status,
        servicePayment: tracking.isServicePayment,
        carWash: tracking.isCarWash
    )
}

private func orderTrackingStatusSubtitle(_ tracking: OrderTrackingDetail) -> String {
    if tracking.courierArrivedAtCustomer,
       tracking.isOnDelivery || tracking.isOutForPickup {
        if tracking.isCarWash {
            return tracking.isOutForPickup
                ? "Comparte tu código de 6 dígitos para entregar el carro"
                : "Abre la Dobbi y comparte tu código de entrega"
        }
        if let code = tracking.deliveryCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return "Comparte tu código de entrega con el repartidor"
        }
        return "Tu pedido te está esperando en la puerta"
    }
    let service = tracking.isServicePayment
    let carWash = tracking.isCarWash
    switch tracking.status.uppercased() {
    case "PENDING":
        return service ? "Procesando tu pago de servicios" : "Esperando confirmación de la tienda"
    case "CONFIRMED":
        if service { return "Tu solicitud fue confirmada" }
        return carWash ? "El carwash aceptó tu servicio" : "Gracias por tu compra"
    case "OUT_FOR_PICKUP":
        if let mins = tracking.estimatedDeliveryMinutes {
            return "El carwash va a recoger tu carro · llegada estimada: ~\(mins) min"
        }
        if let mins = tracking.estimatedPreparationMinutes {
            return "Tiempo estimado para recoger carro: \(mins) min"
        }
        return "El carwash va en camino a recoger tu carro"
    case "PICKED_UP":
        if let mins = tracking.estimatedDeliveryMinutes {
            return "Tu carro va al autolavado · llegada estimada: ~\(mins) min"
        }
        return "Tu carro ya fue recogido y va en camino al autolavado"
    case "PREPARING":
        if let mins = tracking.estimatedPreparationMinutes {
            return carWash
                ? "Tiempo estimado de lavado: \(mins) min"
                : "Tiempo estimado de preparación: \(mins) min"
        }
        return carWash ? "Tu vehículo se está lavando" : "Tu pedido se está preparando"
    case "READY_FOR_PICKUP":
        if service {
            return "Estamos buscando un repartidor para pagar tus servicios"
        }
        return carWash ? "Secado y aspirado en proceso" : "Listo para que el repartidor lo recoja"
    case "ASSIGNED":
        if service {
            if let mins = tracking.estimatedDeliveryMinutes {
                return "Llegada estimada al punto de pago: ~\(mins) min"
            }
            let name = tracking.deliveryMan?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty {
                return "El repartidor \(name) va en camino a pagar tus servicios"
            }
            return "El repartidor va en camino a pagar tus servicios"
        }
        if carWash {
            if let mins = tracking.estimatedDeliveryMinutes {
                return "Detallado en proceso · llegada estimada: ~\(mins) min"
            }
            return "Detallado en proceso"
        }
        if let mins = tracking.estimatedDeliveryMinutes {
            return "Llegada estimada al recoger: ~\(mins) min"
        }
        return "Un repartidor irá por tu pedido pronto"
    case "ON_DELIVERY":
        if let mins = tracking.estimatedDeliveryMinutes {
            return "Llegada estimada: ~\(mins) min"
        }
        if service {
            return "Tus servicios ya fueron pagados y van rumbo a tu domicilio"
        }
        return carWash
            ? "Tu vehículo va en camino a tu domicilio"
            : "Tu pedido va en camino a tu domicilio"
    case "DELIVERED":
        if service { return "Tu pago de servicios fue entregado" }
        return carWash ? "¡Servicio completado!" : "¡Buen provecho!"
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

private func orderStatusLabel(
    _ status: String,
    servicePayment: Bool = false,
    carWash: Bool = false
) -> String {
    switch status.uppercased() {
    case "PENDING": return "Pendiente"
    case "CONFIRMED": return "Confirmado"
    case "OUT_FOR_PICKUP": return carWash ? "En camino" : status
    case "PICKED_UP": return carWash ? "Recogido" : status
    case "PREPARING": return carWash ? "Lavando" : "En preparación"
    case "READY_FOR_PICKUP":
        if servicePayment { return "Buscando repartidor" }
        return carWash ? "Secado y Aspirado" : "Listo para recoger"
    case "ASSIGNED": return carWash ? "Detallado" : "Asignado a repartidor"
    case "ON_DELIVERY": return "En camino"
    case "DELIVERED": return "Entregado"
    case "CANCELLED": return "Cancelado"
    default: return status
    }
}
