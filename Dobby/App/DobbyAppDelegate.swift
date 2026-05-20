//
//  DobbyAppDelegate.swift
//  Dobby
//

import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class DobbyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            DispatchQueue.main.async {
                self.handleProductPromotionPush(userInfo: userInfo)
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Task {
            guard let deps = AppGraph.deps, deps.sessionStore.isLoggedIn else { return }
            await DobbyPushSync.sync(api: deps.httpClient, sessionStore: deps.sessionStore)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("[Dobby push] APNs registration failed: %@", error.localizedDescription)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            await DobbyPushSync.register(fcmToken: fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        postOrderRefresh(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        postOrderRefresh(userInfo: userInfo)
        postOpenOrderTrackingIfNeeded(userInfo: userInfo)
        handleProductPromotionPush(userInfo: userInfo)
        completionHandler()
    }

    private func postOrderRefresh(userInfo: [AnyHashable: Any]) {
        guard isConsumerPushPayload(userInfo) else { return }
        let orderId = orderId(from: userInfo)
        if let orderId {
            NotificationCenter.default.post(
                name: DobbyOrderRealtime.orderChangedNotification,
                object: nil,
                userInfo: ["order_id": orderId]
            )
        } else {
            NotificationCenter.default.post(name: DobbyOrderRealtime.orderChangedNotification, object: nil)
        }
    }

    private func postOpenOrderTrackingIfNeeded(userInfo: [AnyHashable: Any]) {
        let type = pushType(from: userInfo)
        guard type == nil || type == "order_status" || type == "courier_arrived" else { return }
        guard let orderId = orderId(from: userInfo) else { return }
        NotificationCenter.default.post(
            name: DobbyOrderRealtime.openOrderTrackingNotification,
            object: nil,
            userInfo: ["order_id": orderId]
        )
    }

    private func handleProductPromotionPush(userInfo: [AnyHashable: Any]) {
        guard pushType(from: userInfo) == "product_promotion" else { return }
        guard let productId = productId(from: userInfo) else { return }
        let shop = shopId(from: userInfo)
        DobbyOrderRealtime.PendingProductPromotion.store(productId: productId, shopId: shop)
        var info: [String: String] = ["product_id": productId]
        if let shop { info["shop_id"] = shop }
        NotificationCenter.default.post(
            name: DobbyOrderRealtime.openProductPromotionNotification,
            object: nil,
            userInfo: info
        )
    }

    private func isConsumerPushPayload(_ userInfo: [AnyHashable: Any]) -> Bool {
        let type = pushType(from: userInfo)
        return type == nil || type == "order_status" || type == "courier_arrived" || type == "product_promotion"
    }

    private func pushType(from userInfo: [AnyHashable: Any]) -> String? {
        (userInfo["type"] as? String) ?? (userInfo["gcm.notification.type"] as? String)
    }

    private func orderId(from userInfo: [AnyHashable: Any]) -> String? {
        let raw = (userInfo["order_id"] as? String) ?? (userInfo["gcm.notification.order_id"] as? String)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func productId(from userInfo: [AnyHashable: Any]) -> String? {
        let raw = (userInfo["product_id"] as? String) ?? (userInfo["gcm.notification.product_id"] as? String)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func shopId(from userInfo: [AnyHashable: Any]) -> String? {
        let raw = (userInfo["shop_id"] as? String) ?? (userInfo["gcm.notification.shop_id"] as? String)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
