//
//  DobbyPushSync.swift
//  Dobby
//

import FirebaseMessaging
import Foundation

enum DobbyPushSync {
    /// FCM `token()` can hang indefinitely when APNs is not ready (common on Dev).
    private static let syncBudgetNanoseconds: UInt64 = 8_000_000_000

    /// Sends current FCM token to the API and starts Firestore order listener when session is valid.
    /// Never blocks callers for more than `syncBudgetNanoseconds`.
    static func sync(api: DobbyHTTPClient, sessionStore: SessionStore) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await performSync(api: api, sessionStore: sessionStore)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: syncBudgetNanoseconds)
            }
            await group.next()
            group.cancelAll()
        }
    }

    private static func performSync(api: DobbyHTTPClient, sessionStore: SessionStore) async {
        guard sessionStore.isLoggedIn, let bearer = sessionStore.accessToken() else { return }
        do {
            let token = try await Messaging.messaging().token()
            guard !Task.isCancelled else { return }
            _ = await api.registerPushDevice(fcmToken: token, platform: "ios", bearerToken: bearer)
        } catch {
            NSLog("[Dobby push] FCM token failed: %@", error.localizedDescription)
        }
        guard !Task.isCancelled else { return }
        await DobbyOrderRealtime.start(sessionStore: sessionStore, api: api)
    }

    static func register(fcmToken: String) async {
        guard let deps = AppGraph.deps,
              deps.sessionStore.isLoggedIn,
              let bearer = deps.sessionStore.accessToken() else { return }
        _ = await deps.httpClient.registerPushDevice(fcmToken: fcmToken, platform: "ios", bearerToken: bearer)
    }
}
