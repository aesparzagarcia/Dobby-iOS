//
//  HomeBootstrapCache.swift
//  Dobby
//

import Foundation

@MainActor
final class HomeBootstrapCache {
    static let shared = HomeBootstrapCache()

    private var pending: HomeBootstrapSnapshot?

    private init() {}

    func store(_ snapshot: HomeBootstrapSnapshot) {
        pending = snapshot
    }

    func consume() -> HomeBootstrapSnapshot? {
        defer { pending = nil }
        return pending
    }
}
