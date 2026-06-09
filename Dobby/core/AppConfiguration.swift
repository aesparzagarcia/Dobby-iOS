//
//  AppConfiguration.swift
//  Dobby
//

import Foundation
import os.log

enum AppConfiguration {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dobby", category: "API")

    private static let defaultSimulatorBase = "http://127.0.0.1:3001/api/"
    private static let defaultDeviceFallbackBase = "http://127.0.0.1:3001/api/"

    /// Base URL for the Dobby API (same role as Android `BuildConfig.BASE_URL`).
    ///
    /// **Simulator:** `127.0.0.1` is the Mac — default `http://127.0.0.1:3001/api/` when `API_BASE_URL` is unset (matches backend on localhost).
    ///
    /// **Physical device:** Set `API_BASE_URL` to your Mac’s LAN IP (Terminal: `ipconfig getifaddr en0`, often `en0` = Wi‑Fi).
    /// Use `Info.plist` or the Xcode scheme **Environment Variable** `API_BASE_URL` (same key). Do not use `127.0.0.1` on a real iPhone (that is the phone, not the Mac). Backend should listen on `0.0.0.0:3001`.
    ///
    /// Must include scheme, e.g. `http://192.168.1.4:3001/api/`. Bare IPs in Info.plist are normalized automatically.
    static var apiBaseURL: URL {
        let fromEnv = ProcessInfo.processInfo.environment["API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = !fromEnv.isEmpty ? fromEnv : fromPlist

        if let url = resolveAPIBaseURL(from: raw) {
#if !targetEnvironment(simulator)
            let host = url.host ?? ""
            if host == "127.0.0.1" || host.localizedCaseInsensitiveContains("localhost") {
                log.warning("API_BASE_URL uses localhost on a physical device — that is the iPhone, not your Mac. Use your Mac's LAN IP in Info.plist.")
            }
#endif
            return url
        }

#if targetEnvironment(simulator)
        return URL(string: defaultSimulatorBase)!
#else
        log.error("API_BASE_URL vacío o inválido: edita Info.plist (clave API_BASE_URL) con http://<IP-de-tu-Mac>:3001/api/ o define API_BASE_URL en Edit Scheme → Run → Arguments → Environment.")
        return URL(string: defaultDeviceFallbackBase)!
#endif
    }

    /// Normalizes common dev mistakes (`192.168.1.4` → `http://192.168.1.4:3001/api/`).
    private static func resolveAPIBaseURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = normalizeAPIBaseURLString(trimmed)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            log.error("API_BASE_URL no se pudo interpretar: \"\(raw, privacy: .public)\" → \"\(normalized, privacy: .public)\"")
            return nil
        }
        return url
    }

    private static func normalizeAPIBaseURLString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return s }

        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            s = "http://" + s
        }

        guard var components = URLComponents(string: s) else { return s }

        // Dev backend runs on :3001; production HTTPS (Render, etc.) must use default port 443.
        if components.port == nil {
            let scheme = components.scheme?.lowercased() ?? "http"
            if scheme == "http" {
                components.port = 3001
            }
        }

        var path = components.path
        if path.isEmpty || path == "/" {
            path = "/api/"
        } else {
            let normalizedPath = path.hasSuffix("/") ? path : path + "/"
            if !normalizedPath.localizedCaseInsensitiveContains("/api/") {
                path = normalizedPath + "api/"
            } else {
                path = normalizedPath
            }
        }
        components.path = path

        guard let url = components.url else { return s }
        var result = url.absoluteString
        if !result.hasSuffix("/") { result += "/" }
        return result
    }

    /// Origin for relative image paths from the API (matches Android `toDisplayImageUrl`).
    /// Relative `/uploads/...`, and absolute URLs with a stale host (uses path only).
    static func fullImageURL(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathComponent: String
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            guard let url = URL(string: trimmed), !url.path.isEmpty else { return trimmed }
            pathComponent = url.path
        } else {
            pathComponent = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        }
        var base = apiBaseURL.absoluteString
        if base.hasSuffix("/api/") {
            base = String(base.dropLast(5))
        } else if base.hasSuffix("api/") {
            base = String(base.dropLast(4))
        }
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = pathComponent.hasPrefix("/") ? String(pathComponent.dropFirst()) : pathComponent
        return base + "/" + normalizedPath
    }

    /// Persist `/uploads/...` only so changing `API_BASE_URL` does not break cached favorites.
    static func normalizeImageURLForStorage(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            guard let url = URL(string: trimmed), !url.path.isEmpty else { return trimmed }
            return url.path
        }
        return trimmed
    }

    /// Google Places API key (parity with Android `PLACES_API_KEY`). Use `Info.plist` key `PLACES_API_KEY`, or Xcode scheme Environment Variable `PLACES_API_KEY`.
    static var placesAPIKey: String {
        if let env = ProcessInfo.processInfo.environment["PLACES_API_KEY"] {
            let t = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return (Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Google Directions API key (parity with Android `DIRECTIONS_API_KEY`). Prefer a web-service key (not iOS-app-only).
    /// Falls back to `PLACES_API_KEY` when unset, same as Android falling back to `MAPS_API_KEY`.
    static var directionsAPIKey: String {
        if let env = ProcessInfo.processInfo.environment["DIRECTIONS_API_KEY"] {
            let t = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: "DIRECTIONS_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromPlist.isEmpty { return fromPlist }
        return placesAPIKey
    }
}
