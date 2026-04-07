//
//  AccessTokenJwtParser.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.core.auth.AccessTokenJwtParser` — reads JWT `exp` without verifying signature.
//

import Foundation

enum AccessTokenJwtParser {
    /// Returns Unix epoch seconds from the `exp` claim, or nil if missing/invalid.
    static func expiryEpochSeconds(_ jwt: String) -> Int64? {
        let parts = jwt.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let rem = payload.count % 4
        if rem != 0 {
            payload += String(repeating: "=", count: 4 - rem)
        }
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let exp = obj["exp"] as? Int64 {
            return exp >= 0 ? exp : nil
        }
        if let exp = obj["exp"] as? Double {
            let v = Int64(exp)
            return v >= 0 ? v : nil
        }
        return nil
    }
}

extension Notification.Name {
    /// Posted when the session is cleared after a fatal auth failure (refresh missing or invalid).
    static let dobbySessionExpired = Notification.Name("com.ares.Dobby.sessionExpired")
}
