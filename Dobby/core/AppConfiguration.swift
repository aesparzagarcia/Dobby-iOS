//
//  AppConfiguration.swift
//  Dobby
//

import Foundation
import os.log

enum AppConfiguration {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dobby", category: "API")

    /// Base URL for the Dobby API (same role as Android `BuildConfig.BASE_URL`).
    ///
    /// **Simulator:** `127.0.0.1` is the Mac — default `http://127.0.0.1:3001/api/` when `API_BASE_URL` is unset (matches backend on localhost).
    ///
    /// **Physical device:** Add `API_BASE_URL` to `Info.plist` with your Mac’s LAN IP (`ipconfig getifaddr en0`).
    /// Do not use `127.0.0.1` on a real iPhone (that is the phone itself). Backend should listen on `0.0.0.0`.
    static var apiBaseURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !raw.isEmpty, let url = URL(string: raw) {
#if !targetEnvironment(simulator)
            if raw.contains("127.0.0.1") || raw.localizedCaseInsensitiveContains("localhost") {
                log.warning("API_BASE_URL uses localhost on a physical device — that is the iPhone, not your Mac. Use your Mac's LAN IP in Info.plist.")
            }
#endif
            return url
        }

#if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:3001/api/")!
#else
        log.warning("API_BASE_URL missing from Info.plist — using placeholder; set it to your Mac's LAN IP.")
        return URL(string: "http://192.168.1.42:3001/api/")!
#endif
    }

    /// Origin for relative image paths from the API (matches Android `BASE_URL` without `api/`).
    static func fullImageURL(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return path }
        var base = apiBaseURL.absoluteString
        if base.hasSuffix("/api/") {
            base = String(base.dropLast(5))
        } else if base.hasSuffix("api/") {
            base = String(base.dropLast(4))
        }
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base + "/" + trimmed
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
}
