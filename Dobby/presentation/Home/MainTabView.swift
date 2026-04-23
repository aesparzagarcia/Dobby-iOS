//
//  MainTabView.swift
//  Dobby
//

import SwiftUI

enum MainTab: Hashable {
    case home
    case promotions
    case favorites
    case profile
}

private enum MainPalette {
    static let primary = Color(red: 0.45, green: 0.35, blue: 0.75)
    static let barBackground = Color(red: 0.93, green: 0.90, blue: 0.98)
}

struct MainTabView: View {
    let onLogout: () -> Void
    private let placesRepository: PlacesRepository
    private let userAddressRepository: UserAddressRepository
    private let placesAutocompleteRepository: PlacesAutocompleteRepository
    private let orderRepository: OrderRepository
    private let httpClient: DobbyHTTPClient
    private let tokenRefresh: ConsumerTokenRefreshService

    @Environment(\.scenePhase) private var scenePhase
    @State private var proactiveRefreshTask: Task<Void, Never>?

    @State private var tab: MainTab = .home
    /// When `true`, a pushed screen on Home (e.g. shop detail) is active — hide the floating tab bar.
    @State private var homeHidesFloatingTabBar = false
    /// When `true`, product detail or cart is visible on the Promotions tab — hide the floating tab bar.
    @State private var promotionsHidesFloatingTabBar = false
    /// When `true`, product detail or cart is visible on the Favorites tab — hide the floating tab bar.
    @State private var favoritesHidesFloatingTabBar = false
    @State private var homeViewModel: HomeTabViewModel
    @State private var promotionsViewModel: PromotionsTabViewModel
    @State private var favoritesStore: FavoritesStore
    @State private var profileViewModel: ProfileTabViewModel

    init(deps: AppDependencies, onLogout: @escaping () -> Void) {
        self.onLogout = onLogout
        self.placesRepository = deps.placesRepository
        self.userAddressRepository = deps.userAddressRepository
        self.placesAutocompleteRepository = deps.placesAutocompleteRepository
        self.orderRepository = deps.orderRepository
        self.httpClient = deps.httpClient
        self.tokenRefresh = deps.tokenRefresh
        let cartStore = CartLocalStore(container: CartSwiftDataStack.sharedContainer)
        let favoritesLocal = FavoritesLocalStore(container: CartSwiftDataStack.sharedContainer)
        _favoritesStore = State(initialValue: FavoritesStore(local: favoritesLocal))
        _profileViewModel = State(
            initialValue: ProfileTabViewModel(
                profileRepository: deps.profileRepository,
                http: deps.httpClient
            )
        )
        _homeViewModel = State(
            initialValue: HomeTabViewModel(
                placesRepository: deps.placesRepository,
                adsRepository: deps.adsRepository,
                userAddressRepository: deps.userAddressRepository,
                orderRepository: deps.orderRepository,
                http: deps.httpClient,
                cartLocalStore: cartStore
            )
        )
        _promotionsViewModel = State(
            initialValue: PromotionsTabViewModel(
                placesRepository: deps.placesRepository,
                http: deps.httpClient
            )
        )
    }

    var body: some View {
        @Bindable var homeViewModel = homeViewModel
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    HomeTabScreen(
                        viewModel: homeViewModel,
                        placesRepository: placesRepository,
                        favoritesStore: favoritesStore,
                        userAddressRepository: userAddressRepository,
                        placesAutocompleteRepository: placesAutocompleteRepository,
                        orderRepository: orderRepository,
                        httpClient: httpClient,
                        mainTabBarHidden: $homeHidesFloatingTabBar,
                        onCheckoutSuccess: { tab = .home }
                    )
                case .promotions:
                    PromotionsTabScreen(
                        placesRepository: placesRepository,
                        favoritesStore: favoritesStore,
                        promotionsViewModel: promotionsViewModel,
                        homeViewModel: homeViewModel,
                        mainTabBarHidden: $promotionsHidesFloatingTabBar,
                        onCheckoutSuccess: { tab = .home }
                    )
                case .favorites:
                    FavoritesTabScreen(
                        placesRepository: placesRepository,
                        favoritesStore: favoritesStore,
                        homeViewModel: homeViewModel,
                        mainTabBarHidden: $favoritesHidesFloatingTabBar,
                        onCheckoutSuccess: { tab = .home }
                    )
                case .profile:
                    ProfileTabScreen(viewModel: profileViewModel, onLogout: onLogout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowFloatingTabBar {
                FloatingTabBar(selection: $tab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.white)
        .fullScreenCover(isPresented: $homeViewModel.isCheckoutLoading) {
            PlaceOrderLoadingView()
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowFloatingTabBar)
        .onChange(of: scenePhase) { _, phase in
            proactiveRefreshTask?.cancel()
            proactiveRefreshTask = nil
            guard phase == .active else { return }
            proactiveRefreshTask = Task {
                await tokenRefresh.refreshAccessTokenOnForeground()
                while !Task.isCancelled {
                    await tokenRefresh.refreshIfAccessTokenExpiringSoon()
                    try? await Task.sleep(nanoseconds: 3 * 60 * 1_000_000_000)
                }
            }
        }
    }

    /// Tab bar only on root tab screens; hidden while Home or Promotions has a secondary screen pushed.
    private var shouldShowFloatingTabBar: Bool {
        switch tab {
        case .home:
            return !homeHidesFloatingTabBar
        case .promotions:
            return !promotionsHidesFloatingTabBar
        case .favorites:
            return !favoritesHidesFloatingTabBar
        case .profile:
            return true
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, label: "Inicio", systemImage: "house.fill")
            tabButton(.promotions, label: "Promociones", systemImage: "tag.fill")
            tabButton(.favorites, label: "Favoritos", systemImage: "heart.fill")
            tabButton(.profile, label: "Perfil", systemImage: "person.fill")
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(MainPalette.barBackground)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }

    private func tabButton(_ tab: MainTab, label: String, systemImage: String) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection == tab ? MainPalette.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct TabPlaceholderScreen: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(MainPalette.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

