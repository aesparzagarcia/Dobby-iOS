//
//  AppDependencies.swift
//  Dobby
//

import Foundation

struct AppDependencies: Sendable {
    let authRepository: AuthRepository
    let httpClient: DobbyHTTPClient
    let tokenRefresh: ConsumerTokenRefreshService
    let sessionStore: SessionStore
    let placesRepository: PlacesRepository
    let adsRepository: AdsRepository
    let userAddressRepository: UserAddressRepository
    let placesAutocompleteRepository: PlacesAutocompleteRepository
    let profileRepository: ProfileRepository
    let orderRepository: OrderRepository

    static func live() -> AppDependencies {
        let baseURL = AppConfiguration.apiBaseURL
        let sessionStore = SessionStore()
        let urlSession = Self.makeAPISession()
        let httpPlain = DobbyHTTPClient(baseURL: baseURL, session: urlSession)
        let tokenRefresh = ConsumerTokenRefreshService(http: httpPlain, sessionStore: sessionStore)
        let http = DobbyHTTPClient(
            baseURL: baseURL,
            session: urlSession,
            sessionStore: sessionStore,
            tokenRefresh: tokenRefresh
        )
        let authRepository = AuthRepositoryImpl(api: http, sessionStore: sessionStore, tokenRefresh: tokenRefresh)
        let placesRepository = PlacesRepositoryImpl(api: http, sessionStore: sessionStore)
        let adsRepository = AdsRepositoryImpl(api: http, sessionStore: sessionStore)
        let userAddressRepository = UserAddressRepositoryImpl(api: http, sessionStore: sessionStore)
        let placesAutocompleteRepository = PlacesAutocompleteRepositoryImpl(apiKey: AppConfiguration.placesAPIKey)
        let profileRepository = ProfileRepositoryImpl(api: http, sessionStore: sessionStore)
        let orderRepository = OrderRepositoryImpl(api: http, sessionStore: sessionStore)
        return AppDependencies(
            authRepository: authRepository,
            httpClient: http,
            tokenRefresh: tokenRefresh,
            sessionStore: sessionStore,
            placesRepository: placesRepository,
            adsRepository: adsRepository,
            userAddressRepository: userAddressRepository,
            placesAutocompleteRepository: placesAutocompleteRepository,
            profileRepository: profileRepository,
            orderRepository: orderRepository
        )
    }

    /// Avoid indefinite hangs; local network calls still need correct `API_BASE_URL` and `NSLocalNetworkUsageDescription`.
    private static func makeAPISession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }
}
