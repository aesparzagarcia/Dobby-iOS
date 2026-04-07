//
//  SessionStore.swift
//  Dobby
//

import Foundation
import Security

/// Persists access token, refresh token, and user id in the Keychain (parity with Android SessionManager).
final class SessionStore: @unchecked Sendable {
    private let service = "com.ares.Dobby.session"

    private enum Item: String {
        case accessToken = "auth_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }

    var isLoggedIn: Bool {
        let access = read(Item.accessToken) ?? ""
        let refresh = read(Item.refreshToken) ?? ""
        return !access.isEmpty || !refresh.isEmpty
    }

    func saveSession(accessToken: String, refreshToken: String, userId: String?) {
        save(Item.accessToken, accessToken)
        save(Item.refreshToken, refreshToken)
        if let userId {
            save(Item.userId, userId)
        }
    }

    func refreshTokenValue() -> String? {
        let v = read(Item.refreshToken)
        return (v?.isEmpty == false) ? v : nil
    }

    func accessToken() -> String? {
        let v = read(Item.accessToken)
        return (v?.isEmpty == false) ? v : nil
    }

    func clearSession() {
        delete(Item.accessToken)
        delete(Item.refreshToken)
        delete(Item.userId)
    }

    // MARK: - Keychain

    private func save(_ item: Item, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func read(_ item: Item) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ item: Item) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
