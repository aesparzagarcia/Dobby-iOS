//
//  CrashlyticsJourney.swift
//  Dobby
//

import FirebaseCrashlytics
import Foundation

enum CrashlyticsJourney {
    private static var crashlytics: Crashlytics { Crashlytics.crashlytics() }

    static func configure(app: String) {
        crashlytics.setCustomValue(app, forKey: "app")
    }

    static func setScreen(_ name: String) {
        let screen = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !screen.isEmpty else { return }
        crashlytics.setCustomValue(screen, forKey: "last_screen")
        crashlytics.log("screen:\(screen)")
    }

    static func breadcrumb(_ message: String) {
        crashlytics.log(message)
    }

    static func setUserId(_ userId: String?) {
        crashlytics.setUserID(userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}
