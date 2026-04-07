//
//  ProfileDTOs.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.data.remote.model.GamificationDto`.
//

import Foundation

struct GamificationDto: Decodable, Sendable {
    let dobbyXp: Int
    let levelKey: String
    let levelName: String
    let xpAtLevelStart: Int
    let xpForNextLevel: Int?
    let orderStreakDays: Int
    let totalOrdersDelivered: Int
    let name: String?
    let lastName: String?
    let email: String
    let phone: String?
    let recentEvents: [GamificationEventDto]

    enum CodingKeys: String, CodingKey {
        case dobbyXp = "dobby_xp"
        case levelKey = "level_key"
        case levelName = "level_name"
        case xpAtLevelStart = "xp_at_level_start"
        case xpForNextLevel = "xp_for_next_level"
        case orderStreakDays = "order_streak_days"
        case totalOrdersDelivered = "total_orders_delivered"
        case name, email, phone
        case lastName = "last_name"
        case recentEvents = "recent_events"
    }
}

struct GamificationEventDto: Decodable, Sendable {
    let delta: Int
    let reason: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case delta, reason
        case createdAt = "created_at"
    }
}
