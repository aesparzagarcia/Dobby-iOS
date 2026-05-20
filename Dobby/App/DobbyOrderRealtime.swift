//
//  DobbyOrderRealtime.swift
//  Dobby
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

enum DobbyOrderRealtime {
    static let orderChangedNotification = Notification.Name("com.ares.Dobby.orderChanged")
    /// User tapped a push — open `OrderTrackingScreen` for `order_id` in userInfo.
    static let openOrderTrackingNotification = Notification.Name("com.ares.Dobby.openOrderTracking")
    /// User tapped a promotion push — open product detail for `product_id` / `shop_id` in userInfo.
    static let openProductPromotionNotification = Notification.Name("com.ares.Dobby.openProductPromotion")

    /// Holds product deep link until `MainTabView` is ready (cold start from push).
    enum PendingProductPromotion {
        private(set) static var productId: String?
        private(set) static var shopId: String?

        static func store(productId: String, shopId: String?) {
            let id = productId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { return }
            self.productId = id
            let trimmedShop = shopId?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.shopId = (trimmedShop?.isEmpty == false) ? trimmedShop : nil
        }

        static func consume() -> (productId: String, shopId: String?)? {
            guard let id = productId, !id.isEmpty else { return nil }
            let result = (id, shopId)
            productId = nil
            shopId = nil
            return result
        }
    }

    private static var listener: ListenerRegistration?
    private static var listeningUserId: String?

    static func start(sessionStore: SessionStore, api: DobbyHTTPClient) async {
        guard sessionStore.isLoggedIn else {
            stop()
            return
        }
        await signIn(api: api, sessionStore: sessionStore)
        guard let userId = sessionStore.userId()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else { return }
        if userId == listeningUserId, listener != nil { return }

        stop()
        listeningUserId = userId
        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("order_signals")
            .addSnapshotListener { snapshot, _ in
                let orderId = snapshot?.documentChanges.last?.document.documentID
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: orderChangedNotification,
                        object: nil,
                        userInfo: orderId.map { ["order_id": $0] }
                    )
                }
            }
    }

    static func stop() {
        listener?.remove()
        listener = nil
        listeningUserId = nil
    }

    static func signOut() {
        stop()
        try? Auth.auth().signOut()
    }

    private static func signIn(api: DobbyHTTPClient, sessionStore: SessionStore) async {
        guard let bearer = sessionStore.accessToken() else { return }
        let result = await api.fetchFirebaseCustomToken(bearerToken: bearer)
        guard case .success(let token) = result, !token.isEmpty else { return }
        do {
            _ = try await Auth.auth().signIn(withCustomToken: token)
        } catch {
            // Firebase not configured or token invalid.
        }
    }
}
