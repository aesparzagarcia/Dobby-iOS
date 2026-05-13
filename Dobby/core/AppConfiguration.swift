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
    /// **Physical device:** Set `API_BASE_URL` to your Mac’s LAN IP (Terminal: `ipconfig getifaddr en0`, often `en0` = Wi‑Fi).
    /// Use `Info.plist` or the Xcode scheme **Environment Variable** `API_BASE_URL` (same key). Do not use `127.0.0.1` on a real iPhone (that is the phone, not the Mac). Backend should listen on `0.0.0.0:3001`.
    static var apiBaseURL: URL {
        let fromEnv = ProcessInfo.processInfo.environment["API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = !fromEnv.isEmpty ? fromEnv : fromPlist

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
        log.error("API_BASE_URL vacío: edita Info.plist (clave API_BASE_URL) con http://<IP-de-tu-Mac>:3001/api/ o define API_BASE_URL en Edit Scheme → Run → Arguments → Environment. IP del Mac: Terminal → ipconfig getifaddr en0. iPhone y Mac en la misma Wi‑Fi; API en 0.0.0.0:3001; firewall abierto al 3001.")
        return URL(string: "http://127.0.0.1:3001/api/")!
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
