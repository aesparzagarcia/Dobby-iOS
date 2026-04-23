//
//  DobbyPushSync.swift
//  Dobby
//

import FirebaseMessaging
import Foundation

enum DobbyPushSync {
    /// Sends current FCM token to the API when session is valid.
    static func sync(api: DobbyHTTPClient, sessionStore: SessionStore) async {
        guard sessionStore.isLoggedIn, let bearer = sessionStore.accessToken() else { return }
        do {
            let token = try await Messaging.messaging().token()
            _ = await api.registerPushDevice(fcmToken: token, platform: "ios", bearerToken: bearer)
        } catch {
            // Missing GoogleService-Info, permission, or network.
        }
    }

    static func register(fcmToken: String) async {
        guard let deps = AppGraph.deps,
              deps.sessionStore.isLoggedIn,
              let bearer = deps.sessionStore.accessToken() else { return }
        _ = await deps.httpClient.registerPushDevice(fcmToken: fcmToken, platform: "ios", bearerToken: bearer)
    }
}
